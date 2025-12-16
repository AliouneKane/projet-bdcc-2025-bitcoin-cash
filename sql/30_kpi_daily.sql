
--------------------------------------------------------------------
-- Kpi sur les transactions journalières (30 derniers jours)
-------------------------------------------------------------------------


/* ============================================================================
   TABLE : KPI TRANSACTIONS JOURNALIERES (Bitcoin Cash)
   OBJET :
     - Construire une table "prête dashboard" avec les KPI quotidiens.
     - Source : table transactionnelle optimisée `kpi_transactions_days`
       (1 ligne = 1 transaction, + arrays input_addresses/output_addresses)

   NOTE :
     - La table créée est PARTITIONNÉE par `jour` (DATE) pour réduire les scans
       lors des requêtes futures.
============================================================================ */

CREATE OR REPLACE TABLE
  `iconic-parsec-480518-j8.crypto_analytics.kpi_transactions_journalieres_Update`
PARTITION BY jour
AS

/* ============================================================================
   CTE 1 : tx_daily
   Rôle : calculer les KPI JOURNALIERS au niveau des transactions
          (agrégation par DATE(horodatage_bloc))
============================================================================ */
WITH tx_daily AS (
  SELECT
    DATE(horodatage_bloc) AS jour,

    /* ------------------------------------------------------------------------
       KPI 1 : Nombre de transactions par jour (adoption / activité)
       ---------------------------------------------------------------------- */
    COUNT(*) AS nombre_transactions_jour,

    /* ------------------------------------------------------------------------
       KPI 2 : Volume total transféré par jour (proxy on-chain, somme des sorties)
       ⚠️ Sur UTXO, ce volume peut inclure des "change outputs" (sur-estimation).
       ---------------------------------------------------------------------- */
    SUM(valeur_sorties) AS volume_transactions_jour,

    /* ------------------------------------------------------------------------
       KPI 3 : Valeur moyenne d'une transaction (sorties) par jour
       ---------------------------------------------------------------------- */
    AVG(valeur_sorties) AS valeur_moyenne_transaction_jour,

    /* ------------------------------------------------------------------------
       KPI 4 : Valeur médiane d'une transaction (sorties) par jour
       - APPROX_QUANTILES(...,100)[OFFSET(50)] ≈ médiane (P50) avec approximation
       ---------------------------------------------------------------------- */
    APPROX_QUANTILES(valeur_sorties, 100)[OFFSET(50)] AS valeur_mediane_transaction_jour,

    /* ------------------------------------------------------------------------
       KPI 5 : Complexité moyenne (structure des transactions)
       - Définition : total des inputs / total des outputs (ratio des sommes)
       - Interprétation : plus le ratio est élevé, plus les tx ont tendance à
         consommer d’inputs relativement à leurs outputs.
       ---------------------------------------------------------------------- */
    SAFE_DIVIDE(
      SUM(compte_entrees),
      NULLIF(SUM(compte_sorties), 0)
    ) AS complexite_moyenne_input_sur_output,

    /* ------------------------------------------------------------------------
       KPI 6 : Vitesse de circulation (proxy de liquidité)
       - Définition : somme(sorties) / somme(entrées)
       - Interprétation : indicateur interne "flux sortant vs flux entrant".
       ---------------------------------------------------------------------- */
    SAFE_DIVIDE(
      SUM(valeur_sorties),
      SUM(valeur_entrees)
    ) AS vitesse_circulation_proxy_day,

    /* ------------------------------------------------------------------------
       KPI 7 : Proportion de transactions coinbase (création monétaire)
       - Définition : nb_tx_coinbase / nb_total_tx
       - 0  => usage "réel" uniquement ; plus élevé => plus de coinbase dans l'échantillon
       ---------------------------------------------------------------------- */
    SAFE_DIVIDE(
      SUM(CASE WHEN est_coinbase THEN 1 ELSE 0 END),
      COUNT(*)
    ) AS coinbase_inflat,

    /* ------------------------------------------------------------------------
       KPI 8 : Whale Ratio (part du volume porté par "grosses" transactions)
       - Seuil : >= 100 BCH en satoshis => 100 * 1e8 = 10 000 000 000
       - Définition : volume_tx_>=100BCH / volume_total
       ---------------------------------------------------------------------- */
    SAFE_DIVIDE(
      SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END),
      SUM(valeur_sorties)
    ) AS whale_ratio_day

  FROM
    `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`
  GROUP BY
    jour
),

/* ============================================================================
   CTE 2 : adresses_actives
   Rôle : calculer le nombre d'adresses distinctes actives par jour, en prenant :
          - l'union des adresses vues en INPUTS et en OUTPUTS
   Méthode :
     1) UNNEST(input_addresses) => 1 ligne par adresse d'entrée
     2) UNNEST(output_addresses) => 1 ligne par adresse de sortie
     3) UNION DISTINCT => enlève les doublons (même jour, même adresse)
     4) COUNT(DISTINCT adresse) => adresses actives du jour
============================================================================ */
adresses_actives AS (
  WITH adresses AS (

    /* --- Adresses actives côté INPUTS ------------------------------------- */
    SELECT
      DATE(horodatage_bloc) AS jour,
      addr AS adresse
    FROM
      `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`,
      UNNEST(input_addresses) AS addr

    UNION DISTINCT

    /* --- Adresses actives côté OUTPUTS ------------------------------------ */
    SELECT
      DATE(horodatage_bloc) AS jour,
      addr AS adresse
    FROM
      `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`,
      UNNEST(output_addresses) AS addr
  )
  SELECT
    jour,
    COUNT(DISTINCT adresse) AS adresses_actives_jour
  FROM
    adresses
  WHERE
    adresse IS NOT NULL
  GROUP BY
    jour
)

/* ============================================================================
   SELECT FINAL
   Rôle : fusionner les KPI journaliers (tx_daily) avec les adresses actives
          calculées séparément (adresses_actives).
   - LEFT JOIN : on conserve tous les jours de tx_daily, même si aucune adresse
     n’est trouvée (sécurité).
   - COALESCE(...,0) : remplace NULL par 0 lorsque pas de correspondance.
============================================================================ */


SELECT
  d.*,
  COALESCE(a.adresses_actives_jour, 0) AS adresses_actives_jour
FROM
  tx_daily d
LEFT JOIN
  adresses_actives a
USING (jour);
