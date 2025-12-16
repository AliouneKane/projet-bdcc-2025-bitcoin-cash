-- =========================
-- CHECK 1 : Vérifier l'état de la fenêtre (rolling window)
-- Objectif : voir les dates de début et de fin utilisées par le job programmé.
-- =========================



SELECT
  start_date,   -- date de début de la fenêtre (ex : 2019-01-02)
  end_date      -- date de fin de la fenêtre (ex : 2019-01-31)
FROM `iconic-parsec-480518-j8.crypto_analytics.rolling_state`;



-- Cette table "rolling_state" doit normalement contenir UNE SEULE ligne.
-- Si tu exécutes le job, ces deux dates doivent avancer (sliding).


-- ===========================================================================================
-- CHECK 2 : Vérifier le contenu réel de la table Update
-- Objectif : confirmer que crypto_bitcoin_dataset_Update couvre bien la fenêtre attendue
-- (et qu'elle n'est pas vide).
-- =========================



SELECT
  MIN(DATE(horodatage_bloc)) AS min_date_table,  -- premier jour réellement présent dans la table
  MAX(DATE(horodatage_bloc)) AS max_date_table,  -- dernier jour réellement présent dans la table
  COUNT(*) AS nb_lignes                          -- nombre total de transactions dans la table
FROM `iconic-parsec-480518-j8.crypto_analytics.crypto_bitcoin_dataset_Update`;



-- Interprétation :
-- - min_date_table devrait être égal (ou proche) de rolling_state.start_date
-- - max_date_table devrait être égal (ou proche) de rolling_state.end_date
-- - nb_lignes doit être > 0 (sinon : fenêtre sans données, ou problème de filtre/période)
--
-- Note : "proche" car il peut arriver qu'un jour ait très peu voire aucune transaction
-- (rare, mais possible selon la chaîne/période), donc le MIN/MAX peut sauter un jour.
