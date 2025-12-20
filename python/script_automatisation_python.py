import time
from google.cloud import bigquery
import functions_framework

@functions_framework.http
def hello_http(request):
    client = bigquery.Client()
    
    # --- CONFIGURATION DE LA BOUCLE ---
    # 15 répétitions avec une pause très courte (5s) pour un effet "temps réel" rapide
    iterations = 15 
    pause_secondes = 5

    for i in range(iterations):
        try:
            # =================================================================
            # ÉTAPE 1 : Reconstruction de la table avec les bons ALIAS
            # =================================================================
            query_update_table = """
            DECLARE cur_start, cur_end, new_start, new_end, m_start, m_end DATE;
            
            -- 1. Récupération des dates
            SET cur_start = (SELECT start_date FROM `iconic-parsec-480518-j8.crypto_analytics.rolling_state` LIMIT 1);
            SET cur_end = (SELECT end_date FROM `iconic-parsec-480518-j8.crypto_analytics.rolling_state` LIMIT 1);
            
            -- 2. Calcul du Slide (+7 jours)
            SET new_start = DATE_ADD(cur_start, INTERVAL 7 DAY);
            SET new_end = DATE_ADD(cur_end, INTERVAL 7 DAY);
            SET m_start = DATE_TRUNC(new_start, MONTH);
            SET m_end = DATE_TRUNC(new_end, MONTH);

            -- 3. Création de la table avec les noms de colonnes en français (ALIAS AJOUTÉS)
            CREATE OR REPLACE TABLE `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`
            PARTITION BY DATE(horodatage_bloc)
            CLUSTER BY hachage_transaction AS
            SELECT 
                t.hash              AS hachage_transaction, 
                t.block_number      AS numero_bloc, 
                t.block_timestamp   AS horodatage_bloc, 
                t.size              AS taille_bytes, 
                t.virtual_size      AS taille_virtuelle_bytes, 
                t.version           AS version_protocole,
                t.input_count       AS compte_entrees, 
                t.output_count      AS compte_sorties, 
                t.fee               AS frais_transaction, 
                t.is_coinbase       AS est_coinbase,
                SAFE_DIVIDE(t.input_value, 1e8)  AS valeur_entrees, 
                SAFE_DIVIDE(t.output_value, 1e8) AS valeur_sorties,
                
                ARRAY(SELECT DISTINCT addr FROM UNNEST(t.inputs) i CROSS JOIN UNNEST(i.addresses) addr WHERE addr IS NOT NULL) AS input_addresses,
                ARRAY(SELECT DISTINCT addr FROM UNNEST(t.outputs) o CROSS JOIN UNNEST(o.addresses) addr WHERE addr IS NOT NULL) AS output_addresses
            FROM `bigquery-public-data.crypto_bitcoin_cash.transactions` t
            WHERE t.block_timestamp_month BETWEEN m_start AND m_end
              AND t.block_timestamp >= TIMESTAMP(new_start)
              AND t.block_timestamp < TIMESTAMP(DATE_ADD(new_end, INTERVAL 1 DAY));
            """
            client.query(query_update_table).result()

            # =================================================================
            # ÉTAPE 2 : Recalcul des KPI (Daily + Global)
            # =================================================================
            
            # KPI Daily
            query_kpi_daily = """
            CREATE OR REPLACE TABLE `iconic-parsec-480518-j8.crypto_analytics.kpi_transactions_journalieres_Update`
            PARTITION BY jour AS
            WITH tx_daily AS (
                SELECT DATE(horodatage_bloc) AS jour, COUNT(*) AS nombre_transactions_jour, SUM(valeur_sorties) AS volume_transactions_jour,
                AVG(valeur_sorties) AS valeur_moyenne_transaction_jour, APPROX_QUANTILES(valeur_sorties, 100)[OFFSET(50)] AS valeur_mediane_transaction_jour,
                SAFE_DIVIDE(SUM(compte_entrees), NULLIF(SUM(compte_sorties), 0)) AS complexite_moyenne_input_sur_output,
                SAFE_DIVIDE(SUM(valeur_sorties), SUM(valeur_entrees)) AS vitesse_circulation_proxy_day,
                SAFE_DIVIDE(SUM(CASE WHEN est_coinbase THEN 1 ELSE 0 END), COUNT(*)) AS coinbase_inflat,
                SAFE_DIVIDE(SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END), SUM(valeur_sorties)) AS whale_ratio_day
                FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update` GROUP BY jour
            ),
            adresses_actives AS (
                SELECT jour, COUNT(DISTINCT adresse) AS adresses_actives_jour
                FROM (
                    SELECT DATE(horodatage_bloc) AS jour, addr AS adresse FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`, UNNEST(input_addresses) AS addr
                    UNION DISTINCT
                    SELECT DATE(horodatage_bloc) AS jour, addr AS adresse FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`, UNNEST(output_addresses) AS addr
                ) WHERE adresse IS NOT NULL GROUP BY jour
            )
            SELECT d.*, COALESCE(a.adresses_actives_jour, 0) AS adresses_actives_jour FROM tx_daily d LEFT JOIN adresses_actives a USING (jour);
            """
            client.query(query_kpi_daily).result()

            # KPI Global
            query_kpi_global = """
            CREATE OR REPLACE TABLE `iconic-parsec-480518-j8.crypto_analytics.kpi_transactions_globales_Update` AS
            WITH all_addresses AS (
                SELECT addr AS adresse FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`, UNNEST(input_addresses) AS addr
                UNION DISTINCT
                SELECT addr AS adresse FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`, UNNEST(output_addresses) AS addr
            )
            SELECT COUNT(*) AS nombre_transactions_total, SUM(valeur_sorties) AS volume_transactions_total,
            AVG(valeur_sorties) AS valeur_moyenne_transaction, APPROX_QUANTILES(valeur_sorties, 100)[OFFSET(50)] AS valeur_mediane_transaction_total,
            SAFE_DIVIDE(SUM(valeur_sorties), SUM(valeur_entrees)) AS vitesse_circulation_proxy_global,
            SAFE_DIVIDE(SUM(CASE WHEN est_coinbase THEN 1 ELSE 0 END), COUNT(*)) AS coinbase_inflat_global,
            SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END) AS whale_volume_global,
            SAFE_DIVIDE(SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END), SUM(valeur_sorties)) AS whale_ratio_global,
            (SELECT COUNT(DISTINCT adresse) FROM all_addresses WHERE adresse IS NOT NULL) AS adresses_actives_global
            FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`;
            """
            client.query(query_kpi_global).result()

            # =================================================================
            # ÉTAPE 3 : Mise à jour de l'état (le "Slide")
            # =================================================================
            query_update_state = """
            UPDATE `iconic-parsec-480518-j8.crypto_analytics.rolling_state`
            SET start_date = DATE_ADD(start_date, INTERVAL 7 DAY),
                end_date = DATE_ADD(end_date, INTERVAL 7 DAY)
            WHERE TRUE;
            """
            client.query(query_update_state).result()

            # Petite pause de 5 secondes avant le prochain slide
            print(f"Itération {i+1} terminée. Pause de {pause_secondes}s...")
            time.sleep(pause_secondes)

        except Exception as e:
            return f"Erreur à l'itération {i}: {str(e)}", 500

    return "Cycle de simulation rapide terminé avec succès !", 200