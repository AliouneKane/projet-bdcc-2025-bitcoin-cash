# SQL — pipeline BigQuery (Bitcoin Cash)

## Idée générale (concept)
On travaille avec une **fenêtre de temps glissante** (rolling window) pour analyser les transactions sur une période donnée (ex. 30 jours, ou un intervalle défini).  
Pour piloter cette fenêtre, on maintient une petite table d’état appelée **`rolling_state`** qui contient deux dates : **`start_date`** et **`end_date`**.

Le principe est le suivant :
1. **Initialisation** : on crée le dataset et les tables de base, puis on initialise `rolling_state`.
2. **Exécution récurrente (Option A)** : à chaque exécution programmée, on :
   - lit la fenêtre courante dans `rolling_state`,
   - la **fait glisser** (slide) vers l’avant,
   - **reconstruit** la table `crypto_bitcoin_dataset_Update` pour qu’elle contienne uniquement les transactions de la nouvelle fenêtre,
   - **recalcule** les KPI (journalières et globales) à partir de cette table Update,
   - enregistre la nouvelle fenêtre dans `rolling_state`.
3. **Contrôle** : on exécute des requêtes simples (min/max) pour vérifier que la fenêtre et la table Update ont bien évolué.

---

## Fichiers

### 00_setup.sql — Initialisation (one-shot)
Contient les instructions “setup” :
- création du dataset `crypto_analytics` (si nécessaire) ;
- création de la table de base `crypto_bitcoin_dataset` (partitionnée / clusterisée) ;
- création/initialisation de `rolling_state` (dates de la fenêtre de référence).

### 20_scheduled_jobs.sql — Job programmé (Option A)
Script complet destiné à être utilisé dans **BigQuery Scheduled Queries** :
- lit `rolling_state` pour récupérer la fenêtre courante ;
- calcule la nouvelle fenêtre (slide) ;
- reconstruit `crypto_bitcoin_dataset_Update` sur cette nouvelle fenêtre ;
- recalcule les tables KPI “Update” (daily + global) ;
- met à jour `rolling_state`.

### 30_kpi_daily.sql — KPI journalières (Update)
Contient uniquement la requête qui crée/remplace la table de KPI **par jour** (daily), à partir de `crypto_bitcoin_dataset_Update`.

### 31_kpi_global.sql — KPI globales (Update)
Contient uniquement la requête qui crée/remplace la table de KPI **agrégées sur toute la fenêtre** (global), à partir de `crypto_bitcoin_dataset_Update`.

### 90_checks.sql — Contrôles / sanity checks
Requêtes simples de vérification :
- affichage des dates `start_date` / `end_date` dans `rolling_state` ;
- min/max des dates + nombre de lignes dans `crypto_bitcoin_dataset_Update` (pour confirmer que la table suit bien la fenêtre).
