# 🪙 SQL — BigQuery Requests (Bitcoin Cash)

## 🧠 Idée générale (concept)
On analyse la blockchain Bitcoin Cash sur une **fenêtre de temps glissante** (*rolling window*) : une période fixe (ex. ~30 jours) qui avance dans le temps à chaque exécution.

Pour piloter cette fenêtre, on utilise une mini-table d’état : **`rolling_state`**, qui stocke :
- 📅 **`start_date`** : début de la fenêtre  
- 📅 **`end_date`** : fin de la fenêtre  

### 🔄 Comment ça marche (en 3 étapes)
1) 🏗️ **Initialisation**  
   On crée le dataset et les tables de base, puis on initialise `rolling_state`.

2) ⏱️ **Exécution récurrente**  
   À chaque run programmé (Scheduled Query), on :
   - 👀 lit la fenêtre courante dans `rolling_state`,
   - ➡️ la **fait glisser** vers l’avant (*slide*),
   - 🧱 **reconstruit** `crypto_bitcoin_dataset_Update` pour qu’elle contienne **uniquement** les transactions de la nouvelle fenêtre,
   - 📊 **recalcule** les KPI (journaliers + globaux) à partir de cette table Update,
   - 💾 enregistre la nouvelle fenêtre dans `rolling_state`.

3) ✅ **Contrôle**  
   On lance des requêtes simples (min/max + COUNT) pour vérifier que :
   - la fenêtre a bien évolué,
   - la table Update correspond bien aux dates attendues.

---

## 🗂️ Fichiers

### 🧩 00_setup.sql — Initialisation (one-shot)
- 🏷️ création du dataset `crypto_analytics` (si nécessaire)  
- 🧱 création de la table de base `crypto_bitcoin_dataset` (partitionnée / clusterisée)  
- 🗓️ création/initialisation de `rolling_state` (fenêtre de référence)

### 🕒 20_scheduled_jobs.sql — Job programmé (Option A)
Script à utiliser dans **BigQuery Scheduled Queries** :
- 👀 lit `rolling_state` (fenêtre courante)  
- ➡️ calcule la nouvelle fenêtre (*slide*)  
- 🧱 reconstruit `crypto_bitcoin_dataset_Update` sur cette fenêtre  
- 📊 recalcule les KPI “Update” (**daily + global**)  
- 💾 met à jour `rolling_state`

### 📆 30_kpi_daily.sql — KPI journalières (Update)
- 📈 crée/remplace la table de KPI **par jour** (daily)  
- 🔎 source : `crypto_bitcoin_dataset_Update`

### 🌍 31_kpi_global.sql — KPI globales (Update)
- 🧮 crée/remplace la table de KPI **agrégées sur toute la fenêtre** (global)  
- 🔎 source : `crypto_bitcoin_dataset_Update`

### ✅ 90_checks.sql — Contrôles / sanity checks
- 👀 affiche `start_date` / `end_date` depuis `rolling_state`  
- 🔍 vérifie `MIN(date)`, `MAX(date)` et `COUNT(*)` sur `crypto_bitcoin_dataset_Update`  
  (pour confirmer que la table “suit” bien la fenêtre)


## LES KPI calculés

<!-- =========================================================
     DAILY KPIs — Gold Table (conceptual computation)
     Copie/colle dans README.md (GitHub render)
========================================================== -->

<details open>
  <summary><b>✨ KPI journaliers — Méthode de calcul (concept) + interprétation + intérêt BI</b></summary>
  <br/>

  <table style="
    width:100%;
    border-collapse:collapse;
    border:4px solid #D4AF37;
    border-radius:14px;
    overflow:hidden;
  ">
    <thead>
      <tr style="background:#D4AF37; color:#111827;">
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">KPI</th>
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">Méthode de calcul (conceptuelle)</th>
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">Interprétation</th>
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">Intérêt business / BI</th>
      </tr>
    </thead>

   <tbody>
   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🗓️ Jour</b></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Regrouper toutes les transactions par <b>date</b> (jour calendaire du bloc).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Unité d’analyse : 1 ligne = 1 jour.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Support des tendances, saisonnalité, détection de pics/anomalies.
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>📈 Nombre de transactions / jour</b><br/><span style="font-size:12px; color:#cbd5e1;">nombre_transactions_jour</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour donné : <b>compter</b> toutes les transactions confirmées ce jour.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Mesure d’activité réseau (usage).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Indicateur d’adoption. Sert à repérer hausses/baisses soudaines (monitoring).
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>💰 Volume transféré / jour</b><br/><span style="font-size:12px; color:#cbd5e1;">volume_transactions_jour</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour donné : <b>additionner</b> les montants transférés (proxy) de toutes les transactions (ex : total des sorties).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Intensité des transferts (valeur déplacée) sur la journée.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Compare “activité” vs “valeur”. Explique un pic (beaucoup de tx vs quelques grosses tx).
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🧾 Valeur moyenne / tx (jour)</b><br/><span style="font-size:12px; color:#cbd5e1;">valeur_moyenne_transaction_jour</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour donné : <b>volume total du jour</b> ÷ <b>nombre de transactions du jour</b>.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Montant “moyen” par transaction (sensible aux très grosses transactions).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Lecture “retail vs gros transferts”. À comparer à la médiane pour détecter les outliers.
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🎯 Valeur médiane / tx (jour)</b><br/><span style="font-size:12px; color:#cbd5e1;">valeur_mediane_transaction_jour</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour donné : <b>ordonner</b> les montants des transactions et prendre la <b>valeur centrale</b> (50e percentile).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Valeur “typique” — robuste quand il y a des whales.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          KPI clé pour dashboards : stable, comparable dans le temps, moins biaisé que la moyenne.
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🧩 Complexité input/output (jour)</b><br/><span style="font-size:12px; color:#cbd5e1;">complexite_moyenne_input_sur_output</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour : <b>(total des inputs)</b> ÷ <b>(total des outputs)</b> sur l’ensemble des transactions du jour.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Indique la “forme” des transactions (consolidation, fractionnement, patterns techniques).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Détecte des changements de comportement (optimisation, batching, consolidation d’UTXO).
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🔁 Vitesse de circulation (proxy)</b><br/><span style="font-size:12px; color:#cbd5e1;">vitesse_circulation_proxy_day</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour : <b>(valeur totale des sorties)</b> ÷ <b>(valeur totale des entrées)</b>.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Proxy interne de “dynamique des flux” (à interpréter prudemment).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Utile pour comparer jour vs jour et repérer des journées “anormales” en structure de flux.
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>⛏️ Part de coinbase (jour)</b><br/><span style="font-size:12px; color:#cbd5e1;">coinbase_inflat</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour : <b>(nb de transactions coinbase)</b> ÷ <b>(nb total de transactions)</b>.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Part des transactions “structurelles” liées à la production de blocs.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Permet de distinguer l’usage “utilisateur” du bruit lié aux coinbase dans l’échantillon.
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🐳 Whale ratio (jour)</b><br/><span style="font-size:12px; color:#cbd5e1;">whale_ratio_day</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour : <b>volume des “grosses” transactions</b> (≥ 100 BCH) ÷ <b>volume total du jour</b>.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Mesure la domination des grosses transactions dans le volume quotidien.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Explique les pics de volume : hausse organique vs hausse tirée par quelques whales.
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>👥 Adresses actives (jour)</b><br/><span style="font-size:12px; color:#cbd5e1;">adresses_actives_jour</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Pour un jour : <b>lister</b> toutes les adresses vues en entrée et en sortie, puis <b>compter les adresses distinctes</b>.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Proxy de participation/diversité d’acteurs (distinct des transactions).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Complète l’activité : 10k tx avec peu d’adresses ≠ 10k tx avec beaucoup d’adresses.
        </td>
      </tr>
    </tbody>
  </table>

  <p style="margin-top:10px; font-size:12px; color:#6b7280;">
    <b>Note :</b> certains KPI (ex. volume via sorties) sont des <i>proxies on-chain</i> : l’interprétation dépend du contexte UTXO (change outputs, etc.).
  </p>
</details>


<!-- =========================================================
     GLOBAL KPIs — Gold Visual Table (conceptual computation)
     Copie/colle dans README.md (GitHub render)
========================================================== -->

<details open>
  <summary><b>🏆 KPI globaux — Méthode de calcul (concept) + interprétation + intérêt BI</b></summary>
  <br/>

  <table style="
    width:100%;
    border-collapse:collapse;
    border:4px solid #D4AF37;
    border-radius:14px;
    overflow:hidden;
  ">
    <thead>
      <tr style="background:#D4AF37; color:#111827;">
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">KPI</th>
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">Méthode de calcul (conceptuelle)</th>
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">Interprétation</th>
        <th style="border:2px solid #D4AF37; padding:12px; text-align:left;">Intérêt business / BI</th>
      </tr>
    </thead>

   <tbody>
      <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>📦 Nombre total de transactions</b><br/><span style="font-size:12px; color:#cbd5e1;">nombre_transactions_total</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Sur toute la fenêtre : <b>compter</b> toutes les transactions (toutes dates confondues).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Volume d’activité “brut” sur la période observée.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          KPI de synthèse pour comparer des fenêtres (ex. semaine vs semaine, mois vs mois).
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>💰 Volume total transféré</b><br/><span style="font-size:12px; color:#cbd5e1;">volume_transactions_total</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Sur toute la fenêtre : <b>additionner</b> les montants transférés (proxy) de toutes les transactions (ex : total des sorties).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Valeur totale déplacée sur la période.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Mesure “valeur”. Utile pour relier activité et intensité économique (proxy on-chain).
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🧾 Valeur moyenne par transaction</b><br/><span style="font-size:12px; color:#cbd5e1;">valeur_moyenne_transaction</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          <b>Volume total</b> ÷ <b>nombre total de transactions</b> sur la fenêtre.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Montant moyen transféré par transaction (sensible aux grosses transactions).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Profil global “retail vs whales”. À lire avec la médiane.
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🎯 Valeur médiane des transactions</b><br/><span style="font-size:12px; color:#cbd5e1;">valeur_mediane_transaction_total</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Sur toute la fenêtre : <b>ordonner</b> les montants des transactions et prendre le <b>50e percentile</b> (valeur centrale).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Montant “typique” global, robuste aux outliers.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Indicateur de référence très stable pour comparer des périodes.
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🔁 Vitesse de circulation (proxy) globale</b><br/><span style="font-size:12px; color:#cbd5e1;">vitesse_circulation_proxy_global</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Sur la fenêtre : <b>(valeur totale des sorties)</b> ÷ <b>(valeur totale des entrées)</b>.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Proxy global de dynamique de flux (à interpréter prudemment).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          KPI de synthèse pour comparer “structure de flux” entre fenêtres.
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>⛏️ Part coinbase globale</b><br/><span style="font-size:12px; color:#cbd5e1;">coinbase_inflat_global</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          <b>(nombre de transactions coinbase)</b> ÷ <b>(nombre total de transactions)</b> sur la fenêtre.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Poids des transactions de type coinbase dans l’ensemble observé.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Aide à qualifier l’échantillon : part “structurelle” vs usage utilisateur.
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🐳 Whale volume global</b><br/><span style="font-size:12px; color:#cbd5e1;">whale_volume_global</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Sur la fenêtre : <b>additionner</b> les montants des transactions considérées “grosses” (≥ 100 BCH).
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Volume “absolu” attribuable aux whales sur la période.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Donne la taille de l’impact whales (utile même si le ratio reste stable).
        </td>
      </tr>

   <tr style="background:#0f172a; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>🐳 Whale ratio global</b><br/><span style="font-size:12px; color:#cbd5e1;">whale_ratio_global</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          <b>Whale volume</b> ÷ <b>volume total</b> sur la fenêtre.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Part du volume global portée par quelques grosses transactions.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Mesure de concentration : utile pour expliquer des variations de volume entre périodes.
        </td>
      </tr>

   <tr style="background:#0b1220; color:#e5e7eb;">
        <td style="border:2px solid #D4AF37; padding:12px;"><b>👥 Adresses actives globales</b><br/><span style="font-size:12px; color:#cbd5e1;">adresses_actives_global</span></td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Sur la fenêtre : <b>union</b> des adresses vues en entrée et en sortie, puis <b>compter les adresses distinctes</b>.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Proxy de diversité/participation globale d’acteurs sur la période.
        </td>
        <td style="border:2px solid #D4AF37; padding:12px;">
          Complément majeur des volumes : activité élevée avec peu d’adresses ≠ activité répartie.
        </td>
      </tr>
    </tbody>
  </table>

  <p style="margin-top:10px; font-size:12px; color:#6b7280;">
    <b>Note :</b> les KPI “volume” sont des <i>proxies on-chain</i> (UTXO, change outputs). Ils sont très utiles en comparatif, mais s’interprètent avec contexte.
  </p>
</details>
