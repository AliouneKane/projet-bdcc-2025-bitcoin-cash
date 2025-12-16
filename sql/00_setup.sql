-- =============================================================================
-- SCRIPT : BASELINE (STATIC) + ROLLING STATE 
-- Objectif :
--   (1) Créer le dataset (schema) BigQuery
--   (2) Construire la table "crypto_bitcoin_dataset" (table de base)
--   (3) Initialiser / synchroniser rolling_state
--   (4) Calculer les KPI (daily + global) sur la table de base
-- =============================================================================



-- =============================================================================
-- [1] CRÉATION DU DATASET (SCHEMA) DANS BIGQUERY
-- =============================================================================
-- Un "schema" (ou dataset) est comme un dossier dans BigQuery :
-- il regroupe plusieurs tables liées à un même projet.

CREATE SCHEMA IF NOT EXISTS `iconic-parsec-480518-j8.crypto_analytics`
OPTIONS (
  location = 'US',  -- Région de stockage des données (doit être cohérente avec vos ressources)
  description = 'Dataset pour l’analyse des transactions Bitcoin Cash.' -- Description visible dans l’UI
);



-- =============================================================================
-- [2] CRÉATION / REMPLACEMENT DE LA TABLE "CRYPTO_BITCOIN_DATASET"
-- =============================================================================
-- CREATE OR REPLACE :
--   - Si la table existe déjà : elle est supprimée puis recréée
--   - Sinon : elle est créée
-- La table résultante est construite à partir du SELECT ci-dessous.

CREATE OR REPLACE TABLE `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset`

-- PARTITION BY :
--   - BigQuery range physiquement les lignes par jour (DATE)
--   - Réduit fortement le scan des requêtes filtrées par date
PARTITION BY DATE(horodatage_bloc)

-- CLUSTER BY :
--   - Dans chaque partition (jour), BigQuery regroupe les lignes par hash
--   - Peut accélérer certains filtres/join sur hachage_transaction
CLUSTER BY hachage_transaction
AS



-- =============================================================================
-- [3] SÉLECTION DES COLONNES ET TRANSFORMATIONS
-- =============================================================================
SELECT
  -- Identifiant unique de la transaction (hash)
  t.hash AS hachage_transaction,

  -- Numéro du bloc sur la blockchain
  t.block_number AS numero_bloc,

  -- Horodatage du bloc (TIMESTAMP). Sert de base au partitionnement (par jour)
  t.block_timestamp AS horodatage_bloc,

  -- Tailles techniques de la transaction
  t.size AS taille_bytes,
  t.virtual_size AS taille_virtuelle_bytes,

  -- Version du protocole / format transaction
  t.version AS version_protocole,

  -- Nombre d'entrées et de sorties
  t.input_count AS compte_entrees,
  t.output_count AS compte_sorties,

  -- Frais de transaction (souvent en satoshis dans la source)
  t.fee AS frais_transaction,

  -- Indique si la transaction est une coinbase
  t.is_coinbase AS est_coinbase,

  -- --------------------------------------------------------------------------
  -- Conversion satoshis → BCH
  -- --------------------------------------------------------------------------
  -- 1 BCH = 100 000 000 satoshis = 1e8
  -- SAFE_DIVIDE évite une erreur si BigQuery rencontre un cas "anormal"
  SAFE_DIVIDE(t.input_value,  1e8) AS valeur_entrees,
  SAFE_DIVIDE(t.output_value, 1e8) AS valeur_sorties,

  -- --------------------------------------------------------------------------
  -- Extraction des adresses d'entrée (ARRAY<STRING>)
  -- --------------------------------------------------------------------------
  -- t.inputs est un ARRAY de structures; chaque input peut contenir un ARRAY d'adresses.
  -- UNNEST "déplie" les arrays; DISTINCT supprime les doublons; on reconstruit un ARRAY final.
  ARRAY(
    SELECT DISTINCT addr
    FROM UNNEST(t.inputs) i
    CROSS JOIN UNNEST(i.addresses) addr
    WHERE addr IS NOT NULL
  ) AS input_addresses,

  -- --------------------------------------------------------------------------
  -- Extraction des adresses de sortie (ARRAY<STRING>)
  -- --------------------------------------------------------------------------
  ARRAY(
    SELECT DISTINCT addr
    FROM UNNEST(t.outputs) o
    CROSS JOIN UNNEST(o.addresses) addr
    WHERE addr IS NOT NULL
  ) AS output_addresses



-- =============================================================================
-- [4] TABLE SOURCE : TABLE PUBLIQUE BIGQUERY
-- =============================================================================
FROM `bigquery-public-data.crypto_bitcoin_cash.transactions` AS t



-- =============================================================================
-- [5] FILTRES : RÉDUCTION DU COÛT + PRÉCISION DES DATES
-- =============================================================================
WHERE
  -- Filtre de partition mensuelle (très important pour réduire le volume scanné) :
  -- - block_timestamp_month correspond au mois (DATE du 1er jour du mois)
  -- - Filtrer dessus force BigQuery à ne lire que les partitions mensuelles utiles
  --
  -- ⚠️ Note : le mois '2012-01-01' peut être hors période pour Bitcoin Cash.
  -- En pratique, utiliser un mois existant dans la source.
  t.block_timestamp_month = DATE '2012-01-01'

  -- Filtre exact sur la fenêtre (précision timestamp) :
  -- - Début inclus
  -- - Fin exclue (pattern recommandé)
  AND t.block_timestamp >= TIMESTAMP('2012-01-01 00:00:00 UTC')
  AND t.block_timestamp <  TIMESTAMP('2012-02-01 00:00:00 UTC');





-- =============================================================================
-- [6] ROLLING STATE : synchronisation (min/max) avec la table Update
-- =============================================================================
-- Objectif :
--   - Recréer rolling_state pour qu’elle reflète exactement l’étendue temporelle
--     (min et max) de la table crypto_bitcoin_dataset_Update.
-- Remarque :
--   - Si crypto_bitcoin_dataset_Update est vide, start_date/end_date seront NULL.

CREATE OR REPLACE TABLE `iconic-parsec-480518-j8.crypto_analytics.rolling_state` AS
SELECT
  MIN(DATE(horodatage_bloc)) AS start_date,
  MAX(DATE(horodatage_bloc)) AS end_date
FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset`;

