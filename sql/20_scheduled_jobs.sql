-- =============================================================================
-- 20_scheduled_job_optionA.sql
-- Objectif :
--   1) Lire la fenêtre courante dans rolling_state
--   2) Calculer la nouvelle fenêtre (slide)
--   3) Reconstruire crypto_bitcoin_dataset_Update pour la nouvelle fenêtre
--   4) Recalculer les KPI (Daily + Global) basées sur la table Update
--   5) Mettre à jour rolling_state
--
-- Note :
--   - A noter que la table "Update" ici est une copie de la table crypto_bitcoin_dataset_Update
-- =============================================================================



-- =============================================================================
-- [0] DÉCLARATION DES VARIABLES
-- =============================================================================
-- Variables de fenêtre : dates courantes (cur_*) et nouvelles (new_*)
DECLARE cur_start DATE;
DECLARE cur_end   DATE;
DECLARE new_start DATE;
DECLARE new_end   DATE;

-- Variables "mois" : utilisées pour filtrer block_timestamp_month et réduire le scan
DECLARE m_start   DATE;
DECLARE m_end     DATE;



-- =============================================================================
-- [1] LECTURE DE LA FENÊTRE ACTUELLE DANS ROLLING_STATE
-- =============================================================================
SET cur_start = (
  SELECT start_date FROM `iconic-parsec-480518-j8.crypto_analytics.rolling_state` LIMIT 1
);

SET cur_end = (
  SELECT end_date FROM `iconic-parsec-480518-j8.crypto_analytics.rolling_state` LIMIT 1
);



-- =============================================================================
-- [2] SLIDE DE LA FENÊTRE (DÉCALAGE TEMPOREL)
-- =============================================================================
-- Ici : slide de 7 jours (1 semaine)
SET new_start = DATE_ADD(cur_start, INTERVAL 7 DAY);
SET new_end   = DATE_ADD(cur_end,   INTERVAL 7 DAY);

-- Calcul des mois couverts par la nouvelle fenêtre (utile pour pruner la partition mensuelle)
SET m_start = DATE_TRUNC(new_start, MONTH);
SET m_end   = DATE_TRUNC(new_end,   MONTH);



-- =============================================================================
-- [3] RECONSTRUCTION DE LA TABLE "crypto_bitcoin_dataset_Update"
-- =============================================================================
-- Objectif :
--   - Reconstruire entièrement la table Update pour qu'elle contienne UNIQUEMENT
--     les transactions dont le block_timestamp est dans [new_start ; new_end]
--   - Optimisation : filtre sur block_timestamp_month (partition mensuelle)
--   - Optimisation : partitionnement (jour) + clustering (hash)
CREATE OR REPLACE TABLE `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`
PARTITION BY DATE(horodatage_bloc)
CLUSTER BY hachage_transaction
AS
SELECT
  -- Colonnes "transaction"
  t.hash            AS hachage_transaction,
  t.block_number    AS numero_bloc,
  t.block_timestamp AS horodatage_bloc,

  -- Métadonnées techniques
  t.size            AS taille_bytes,
  t.virtual_size    AS taille_virtuelle_bytes,
  t.version         AS version_protocole,

  -- Structure de la transaction
  t.input_count     AS compte_entrees,
  t.output_count    AS compte_sorties,

  -- Frais et coinbase
  t.fee             AS frais_transaction,
  t.is_coinbase     AS est_coinbase,

  -- Conversion satoshis -> BCH (1 BCH = 1e8 satoshis)
  SAFE_DIVIDE(t.input_value,  1e8) AS valeur_entrees,
  SAFE_DIVIDE(t.output_value, 1e8) AS valeur_sorties,

  -- Adresses d'entrée : ARRAY<STRING> (uniques, non nulles)
  ARRAY(
    SELECT DISTINCT addr
    FROM UNNEST(t.inputs) i
    CROSS JOIN UNNEST(i.addresses) addr
    WHERE addr IS NOT NULL
  ) AS input_addresses,

  -- Adresses de sortie : ARRAY<STRING> (uniques, non nulles)
  ARRAY(
    SELECT DISTINCT addr
    FROM UNNEST(t.outputs) o
    CROSS JOIN UNNEST(o.addresses) addr
    WHERE addr IS NOT NULL
  ) AS output_addresses

FROM `bigquery-public-data.crypto_bitcoin_cash.transactions` t
WHERE
  -- (1) Filtre de partition mensuelle : réduit fortement le volume scanné
  t.block_timestamp_month BETWEEN m_start AND m_end

  -- (2) Filtre exact de fenêtre (TIMESTAMP) :
  --     - début inclus
  --     - fin exclue (au lendemain 00:00:00)
  AND t.block_timestamp >= TIMESTAMP(new_start)
  AND t.block_timestamp <  TIMESTAMP(DATE_ADD(new_end, INTERVAL 1 DAY));



-- =============================================================================
-- [4] KPI "DAILY" (basées sur crypto_bitcoin_dataset_Update)
-- =============================================================================

 --- Kpi sur les transactions journalières (30 derniers jours)

/* ============================================================================
   TABLE : KPI TRANSACTIONS JOURNALIERES (Bitcoin Cash)
   OBJET :
     - Construire une table "prête dashboard" avec les KPI quotidiens.
     - Source : crypto_bitcoin_dataset_Update
   NOTE :
     - La table créée est PARTITIONNÉE par `jour` (DATE)
============================================================================ */

CREATE OR REPLACE TABLE
  `iconic-parsec-480518-j8.crypto_analytics.kpi_transactions_journalieres_Update`
PARTITION BY jour
AS

/* ============================================================================
   CTE 1 : tx_daily
   Rôle : calculer des KPI par jour au niveau des transactions
============================================================================ */
WITH tx_daily AS (
  SELECT
    DATE(horodatage_bloc) AS jour,

    -- KPI 1 : Nombre de transactions par jour
    COUNT(*) AS nombre_transactions_jour,

    -- KPI 2 : Volume total transféré par jour (proxy on-chain)
    SUM(valeur_sorties) AS volume_transactions_jour,

    -- KPI 3 : Valeur moyenne des transactions (sorties)
    AVG(valeur_sorties) AS valeur_moyenne_transaction_jour,

    -- KPI 4 : Valeur médiane (approx.) des transactions (sorties)
    APPROX_QUANTILES(valeur_sorties, 100)[OFFSET(50)] AS valeur_mediane_transaction_jour,

    -- KPI 5 : Complexité moyenne (ratio inputs / outputs)
    SAFE_DIVIDE(
      SUM(compte_entrees),
      NULLIF(SUM(compte_sorties), 0)
    ) AS complexite_moyenne_input_sur_output,

    -- KPI 6 : Vitesse de circulation proxy (sorties / entrées)
    SAFE_DIVIDE(
      SUM(valeur_sorties),
      SUM(valeur_entrees)
    ) AS vitesse_circulation_proxy_day,

    -- KPI 7 : Proportion coinbase
    SAFE_DIVIDE(
      SUM(CASE WHEN est_coinbase THEN 1 ELSE 0 END),
      COUNT(*)
    ) AS coinbase_inflat,

    -- KPI 8 : Whale ratio (transactions >= 100 BCH)
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
   Rôle : compter les adresses distinctes actives par jour (inputs ∪ outputs)
============================================================================ */
adresses_actives AS (
  WITH adresses AS (

    -- Adresses actives côté INPUTS
    SELECT
      DATE(horodatage_bloc) AS jour,
      addr AS adresse
    FROM
      `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`,
      UNNEST(input_addresses) AS addr

    UNION DISTINCT

    -- Adresses actives côté OUTPUTS
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

-- ============================================================================
-- SELECT FINAL : jointure des KPI journaliers + adresses actives
-- ============================================================================
SELECT
  d.*,
  COALESCE(a.adresses_actives_jour, 0) AS adresses_actives_jour
FROM
  tx_daily d
LEFT JOIN
  adresses_actives a
USING (jour);



-- =============================================================================
-- [5] KPI "GLOBAL" (basées sur crypto_bitcoin_dataset_Update)
-- =============================================================================

--  Kpi sur les transactions agrégées des 30 derniers jours

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
  -- KPI 1 : Nombre total de transactions
  COUNT(*) AS nombre_transactions_total,

  -- KPI 2 : Volume total (proxy) : somme des sorties
  SUM(valeur_sorties) AS volume_transactions_total,

  -- KPI 3 : Valeur moyenne (sorties)
  AVG(valeur_sorties) AS valeur_moyenne_transaction,

  -- KPI 4 : Valeur médiane (approx.) des transactions (sorties)
  APPROX_QUANTILES(valeur_sorties, 100)[OFFSET(50)] AS valeur_mediane_transaction_total,

  -- KPI 5 : Vitesse de circulation proxy globale (sorties / entrées)
  SAFE_DIVIDE(SUM(valeur_sorties), SUM(valeur_entrees)) AS vitesse_circulation_proxy_global,

  -- KPI 6 : Proportion coinbase globale
  SAFE_DIVIDE(SUM(CASE WHEN est_coinbase THEN 1 ELSE 0 END), COUNT(*)) AS coinbase_inflat_global,

  -- KPI 7 : Whale volume global (transactions >= 100 BCH)
  SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END) AS whale_volume_global,

  -- KPI 8 : Whale ratio global
  SAFE_DIVIDE(
    SUM(CASE WHEN valeur_sorties >= 100 THEN valeur_sorties ELSE 0 END),
    SUM(valeur_sorties)
  ) AS whale_ratio_global,

  -- KPI 9 : Nombre d'adresses distinctes global (inputs ∪ outputs)
  (SELECT COUNT(DISTINCT adresse) FROM all_addresses WHERE adresse IS NOT NULL)
    AS adresses_actives_global

FROM
  `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`;



-- =============================================================================
-- [6] MISE À JOUR DE rolling_state
-- =============================================================================
-- Objectif :
--   - Enregistrer la nouvelle fenêtre (new_start / new_end) dans rolling_state
-- Note :
--   - WHERE TRUE est utilisé car certaines politiques exigent un WHERE sur UPDATE
UPDATE `iconic-parsec-480518-j8.crypto_analytics.rolling_state`
SET start_date = new_start,
    end_date   = new_end
WHERE TRUE;
