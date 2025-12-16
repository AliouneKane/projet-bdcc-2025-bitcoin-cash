# 🚀 Projet BDCC 2025 : Analyse BI en Temps Réel - Bitcoin Cash

**Entreprise :** ChainSight Solutions
**Projet :** Monitoring de Liquidité et Activité Blockchain

## 📋 Description du Projet
Ce projet s'inscrit dans le cadre du cours de "Big Data & Cloud Computing". Il vise à démontrer une architecture **Serverless** sur **Google Cloud Platform (GCP)** pour transformer des données brutes de la Blockchain Bitcoin Cash en indicateurs décisionnels (KPIs) en temps réel.

**Problématique :**
> *"Comment l'analyse en temps réel des mouvements de liquidité et de l'activité transactionnelle sur la blockchain Bitcoin Cash peut-elle permettre d'anticipiter les tendances de marché et d'optimiser les stratégies d'investissement ?"*

## 🛠️ Architecture Technique
* **Source de Données :** `bigquery-public-data.crypto_bitcoin_cash` (Google Cloud Public Datasets).
* **Data Warehouse :** Google BigQuery (Stockage & Calcul).
* **Visualisation :** Looker Studio (Dashboard Dynamique).
* **Langage :** SQL Standard (GoogleSQL).

## 📊 KPIs & Analyse
Le projet calcule 9 KPIs majeurs basés sur l'activité on-chain :
1.  **KPIs Journaliers** (pour suivre l'évolution quotidienne).
2.  **KPIs Globaux** (pour une vue agrégée sur 30 jours).

*Exemples de métriques :* Whale Ratio, Vitesse de circulation, Adresses actives.

## 🚀 Installation & Configuration Rapide
1.  Cloner ce dépôt.
2.  Disposer d'un projet GCP actif (BigQuery Sandbox).
3.  Exécuter les scripts dans le dossier `/sql` dans l'ordre numérique via la console BigQuery.
4.  Connecter les tables de sortie (`kpi_transactions_journalieres`) à Looker Studio.

*(Voir le dossier `/docs` pour la documentation technique complète et le guide pas à pas).*

## 👥 Auteurs (Équipe)
* Alioune Abdou Salam KANE
* Ameth FAYE
* Khadidiatou COULIBALY
* Haba Fromo Francis
* Awa DIAW"# projet-bdcc-2025-bitcoin-cash" 
