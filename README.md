# Projet BDCC 2025 : Utilisation de Google BigQuery pour des rapports BI en temps réel - Bitcoin Cash

**Sous la supervision de:** Mme Mously Diaw, Senior ML Engineer  
**Entreprise :** ChainSight Solutions  
**Projet :** Monitoring de Liquidité et Activité Blockchain

---

## 📝 Description du Projet

Ce projet s'inscrit dans le cadre du cours de **" d'initiation au Big Data et au Cloud Computing"**. L'objectif central est de démontrer l'utilisation de **Google BigQuery** pour générer des rapports BI en temps réel.

Dans l'atteinte de cet objectif, nous travaillons avec une base de données sur la cryptomonnaie (**Bitcoin Cash**) pour laquelle nous avons défini la problématique métier suivante :

> *"Comment l'analyse en temps réel des mouvements de liquidité et de l'activité transactionnelle sur la blockchain Bitcoin Cash peut-elle permettre d'anticiper les tendances de marché et d'optimiser les stratégies d'investissement ?"*

En construisant ce pipeline analytique, nous démontrons la capacité technique à transformer des données brutes massives en un avantage décisionnel instantané pour les investisseurs opérant sur des marchés à haute volatilité.

---

## 🔗 Liens Utiles

* 🚀 **[Dashboard Interactif (Looker Studio)](https://lookerstudio.google.com/reporting/33b9b3cd-b150-4e83-93cd-6a826038541e/page/p_fg61dhy2yd?s=rQuNFeieiTE)** : Visualisation des KPIs et des tendances on-chain.
* 🌐 **[Site Vitrine du Projet (ChainSight Pulse)](https://chain-sight-pulse.lovable.app)** : Présentation détaillée de la solution et du contexte métier.

---

## 📂 Structure du Répertoire

```text
projet-bdcc-2025-bitcoin-cash/
├── sql/                        # Scripts de traitement de données (BigQuery)
│   ├── 00_setup.sql            # Initialisation du schéma et de la table source
│   ├── 20_scheduled_jobs.sql   # Logique pour l'automatisation temporelle
│   ├── 30_kpi_daily.sql        # Calcul des indicateurs journaliers
│   ├── 31_kpi_global.sql       # Calcul des indicateurs agrégés (30 jours)
│   ├── 90_checks.sql           # Requêtes de vérification et tests de données
│   └── readme.md               # Documentation spécifique au dossier SQL
├── docs/                       # Documentation technique détaillée
│   └── documentation_technique.pdf
├── python/
    └── script_automatisation_python.py # Dossier contenant la Cloud Function pour le pilotage automatisé du pipeline
└── README.md                   # Documentation principale du projet

```

---

## ⚙️ Détail des Scripts SQL

Chaque fichier dans le dossier `/sql` remplit une fonction précise dans le pipeline :

* **`00_setup.sql`** : Création du dataset de destination et de la table principale partitionnée pour optimiser les performances de lecture.
* **`20_scheduled_jobs.sql`** : Logique de planification pour simuler le flux de données en temps réel.
* **`30_kpi_daily.sql`** : Calcul des indicateurs quotidiens (Volume, Whale Ratio, Adresses actives) pour le dashboard.
* **`31_kpi_global.sql`** : Génération d'une vue d'ensemble synthétique sur l'ensemble de la période d'analyse.
* **`90_checks.sql`** : Scripts de diagnostic pour valider l'intégrité des données avant la phase de visualisation.

---

## 🏗️ Architecture Technique

* **Source de Données** : `bigquery-public-data.crypto_bitcoin_cash` (Google Cloud Public Datasets).
* **Data Warehouse** : **Google BigQuery** (Stockage et Calcul Serverless).
* **Visualisation** : **Looker Studio** (Dashboard Dynamique).
* **Langage** : SQL Standard (GoogleSQL).

---

## 📊 KPIs et Analyse

Le projet suit notamment les indicateurs clés suivants :

1. **Whale Ratio** : Mesure la proportion du volume total porté par les transactions supérieures ou égales à 100 BCH.
2. **Vitesse de circulation** : Analyse du ratio des flux entrants et sortants pour évaluer la dynamique de liquidité.
3. **Adresses Actives** : Suivi du nombre d'utilisateurs uniques pour mesurer l'adoption réelle du réseau.

---

## 🔄 Automatisation & Simulation Temps Réel
Le dossier /python contient un script (script_automatisation_python.py) conçu pour être déployé en tant que Cloud Function.

1. **Mécanisme de Slide** : Le script met à jour une table de configuration rolling_state en ajoutant 7 jours à chaque itération.
2.**Cycle de Vie** : Il reconstruit automatiquement les tables de données et recalcule les KPIs (journaliers et globaux) pour chaque nouvelle période.
3.**Performance** : Configuration actuelle de 15 itérations avec une pause de 5 secondes pour observer la dynamique sur Looker Studio.

---


## 🚀 Installation et Configuration Rapide

1. **Cloner** ce dépôt sur votre machine locale.
2. Disposer d'un projet **Google Cloud Platform** actif (BigQuery Sandbox suffit).
3. Lire la **documentation technique** située dans le dossier `/docs` dans son entièreté.
4. Exécuter les scripts du dossier `/sql` dans **l'ordre numérique** (00 -> 20 -> 30) via la console BigQuery Studio.
5. Connecter **Looker Studio** aux tables résultantes situées dans le dataset `crypto_analytics`.

---


## 👥 Auteurs (Équipe)

* **Alioune Abdou Salam KANE**
* **Ameth FAYE**
* **Khadidiatou COULIBALY**
* **Haba Fromo Francis**
* **Awa DIAW**


