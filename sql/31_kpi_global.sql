
--------------------------------------------------------------------
-- Kpi sur les transactions agrégées des 30 derniers jours
-------------------------------------------------------------------------

CREATE OR REPLACE TABLE
  `iconic-parsec-480518-j8.crypto_analytics.kpi_transactions_globales_Update`
AS
WITH all_addresses AS (
  -- Inputs : une ligne par adresse
  SELECT addr AS adresse
  FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`,
  UNNEST(input_addresses) AS addr

  UNION DISTINCT

  -- Outputs : une ligne par adresse
  SELECT addr AS adresse
  FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`,
  UNNEST(output_addresses) AS addr
)
SELECT
  /* ---------------- KPI GLOBAUX ---------------- */

  -- KPI 1 : Nombre total de transactions
  COUNT(*) AS nombre_transactions_total,

  -- KPI 2 : Volume total (proxy) : somme des sorties
  SUM(valeur_sorties) AS volume_transactions_total,

  -- KPI 3 : Valeur moyenne (sorties)
  AVG(valeur_sorties) AS valeur_moyenne_transaction,

  -- KPI 4 : Valeur médiane (sorties)
  APPROX_QUANTILES(valeur_sorties, 100)[OFFSET(50)] AS valeur_mediane_transaction_total,

  -- KPI 5 : "Vitesse de circulation" proxy : total sorties / total entrées
  SAFE_DIVIDE(SUM(valeur_sorties), SUM(valeur_entrees)) AS vitesse_circulation_proxy_global,

  -- KPI 6 : Proportion coinbase (inflation/émission vs usage)
  SAFE_DIVIDE(SUM(CASE WHEN est_coinbase THEN 1 ELSE 0 END), COUNT(*)) AS coinbase_inflat_global,

  -- KPI 7 : Whale volume (>= 100 BCH) en satoshis
  SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END) AS whale_volume_global,


  -- KPI 8 : Whale ratio global = part du volume de transactions total portée par les whales
  SAFE_DIVIDE(
    SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END),
    SUM(valeur_sorties)
  ) AS whale_ratio_global,

  -- KPI 9 : Nombre d'adresses distinctes global (inputs ∪ outputs)
  (SELECT COUNT(DISTINCT adresse) FROM all_addresses WHERE adresse IS NOT NULL)
    AS adresses_actives_global

FROM
  `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`;

