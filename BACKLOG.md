# Backlog — LudoPayApp

> Application mobile Flutter (Android + iOS) de caisse simplifiée avec impression thermique Bluetooth.
> Toutes les données sont stockées localement (SQLite). Zéro dépendance réseau.

---

## Légende

| Statut | Symbole |
|---|---|
| À faire | `[ ]` |
| En cours | `[~]` |
| Terminé | `[x]` |
| Bloqué | `[!]` |

---

## EPIC 0 — Initialisation du projet

- [x] **E0-1** Créer le projet Flutter (`flutter create --org com.jcbpartner --platforms android,ios`)
- [x] **E0-2** Configurer les dépendances `pubspec.yaml`
  - `flutter_riverpod 2.6.1`
  - `sqflite 2.4.2`
  - `path 1.9.1`
  - `intl 0.20.2`
  - `shared_preferences 2.5.3`
  - _(Bluetooth printing : différé à E3 après POC)_
- [x] **E0-3** Mettre en place l'architecture des dossiers (`features/`, `core/`, `shared/`)
- [x] **E0-4** Initialiser la base de données SQLite (schéma complet : produits, journees, ventes, ventes_lignes)
- [x] **E0-5** Configurer la navigation (bottom nav bar 3 onglets + page imprimante via AppBar)
- [x] **E0-6** Configurer les permissions AndroidManifest (Bluetooth Classic + BLE, Android 12+ et legacy)
- [x] **E0-7** Configurer les permissions iOS Info.plist (NSBluetoothAlwaysUsageDescription)

---

## EPIC 1 — Gestion des produits

- [x] **E1-1** Modèle `Produit` + repository SQLite (CRUD + champ `ordre`)
- [x] **E1-2** Provider Riverpod `ProduitsNotifier` (liste réactive)
- [x] **E1-3** Écran liste des produits (affichage nom + prix)
- [x] **E1-4** Drag & drop pour réorganiser l'ordre (`onReorderItem`, sauvegarde batch)
- [x] **E1-5** Modal "Ajouter un produit" (nom + prix TTC, validation)
- [x] **E1-6** Modal "Modifier un produit" (pré-remplie, même composant)
- [x] **E1-7** Swipe gauche → suppression avec dialog de confirmation
  - Règle : si le produit apparaît dans des ventes passées → désactivation (`actif = false`) plutôt que suppression physique

---

## EPIC 2 — Panier & enregistrement des ventes

- [x] **E2-1** Modèle `Panier` (état local Map<id,qté>, non persisté)
- [x] **E2-2** Provider Riverpod `PanierNotifier` (incrementer, decrementer, vider, calculerTotal)
- [x] **E2-3** Écran panier : liste des produits avec boutons `[-]` / `[+]`
- [x] **E2-4** Affichage du total TTC en bas (mis à jour en temps réel)
- [x] **E2-5** Bouton "Vider" avec dialog de confirmation
- [x] **E2-6** Modèles `Vente` + `VenteLigne` + `Journee` + `VentesRepository`
- [x] **E2-7** Gestion des journées : `getOrCreateJourneeAujourdhui()` automatique
- [x] **E2-8** `VenteService.enregistrer()` — transaction atomique SQLite + maj agrégats journée

---

## EPIC 3 — Impression thermique Bluetooth

- [ ] **E3-1** POC : scan BLE, connexion à la NETUM NT-1809DD, identifier les UUID GATT
- [ ] **E3-2** Service `ImprimanteService` : scan, connexion, déconnexion, persistance du choix
- [ ] **E3-3** Écran paramètres imprimante (liste appareils BT, bouton scanner, statut connexion)
- [ ] **E3-4** Bouton "Test ticket" (impression d'un ticket de test)
- [ ] **E3-5** Reconnexion automatique au lancement si imprimante mémorisée
- [ ] **E3-6** Service `TicketService` : formatage ESC/POS du ticket
  - En-tête (nom app, date, heure)
  - Lignes produits (nom × qté → sous-total)
  - Séparateurs
  - Total TTC
  - Pied de page ("Merci !")
  - Coupe papier
- [ ] **E3-7** Flux complet bouton "Imprimer" :
  - Vérification panier non vide
  - Vérification imprimante connectée (sinon : popup + lien vers ⚙️)
  - Impression du ticket
  - Enregistrement de la vente (appel `VenteService`)
  - RAZ du panier
  - Toast de confirmation

---

## EPIC 4 — Rapport journalier

- [ ] **E4-1** Requêtes SQLite agrégées : CA jour, nb ventes, quantités par produit
- [ ] **E4-2** Provider Riverpod `RapportNotifier`
- [ ] **E4-3** Écran rapport :
  - En-tête : date du jour, CA total, nombre de ventes
  - Section "Produits vendus" : liste nom × qté → total par produit, triée par qté décroissante
  - Section "Historique des ventes" : liste chronologique (heure + total)
- [ ] **E4-4** Tap sur une vente → bottom sheet avec le détail des lignes
- [ ] **E4-5** Bouton "Clôturer la journée" :
  - Dialog de confirmation
  - Archivage (`journees.cloturee_le = NOW`)
  - Création automatique d'une nouvelle journée
  - Rafraîchissement du rapport (repart à zéro)

---

## EPIC 5 — Qualité & finalisation

- [ ] **E5-1** Gestion des erreurs Bluetooth (perte de connexion pendant impression)
- [ ] **E5-2** Validation des formulaires (nom non vide, prix > 0, format numérique)
- [ ] **E5-3** États vides (liste produits vide → message + CTA, panier vide → message)
- [ ] **E5-4** Icône de l'application (Android + iOS)
- [ ] **E5-5** Nom de l'app configurable (ticket + app bar)
- [ ] **E5-6** Tests sur device Android physique
- [ ] **E5-7** Tests sur device iOS physique (validation BLE)
- [ ] **E5-8** Build Android (`.apk` / `.aab`)
- [ ] **E5-9** Build iOS (`.ipa`)

---

## Ordre d'itération suggéré

```
Itération 1 — Squelette & données
  E0 complet → E1 complet → E2-1 à E2-8

Itération 2 — Panier & rapport (sans impression)
  E2-3 à E2-8 → E4 complet
  → L'app est déjà utilisable hors impression

Itération 3 — Impression Bluetooth
  E3-1 (POC) → E3-2 à E3-7
  → Valider le BLE iOS en priorité

Itération 4 — Finitions
  E5 complet
```

---

## Notes techniques

- **Snapshot prix/nom** : les `ventes_lignes` stockent le nom et prix au moment de la vente. Un changement de prix ultérieur n'altère pas l'historique.
- **Suppression produit** : si `ventes_lignes` référencent le produit → `actif = false` (masqué du panier et de la liste) plutôt que `DELETE`.
- **Journée courante** : déterminée par `DATE('now')`. Créée automatiquement si absente au premier lancement du jour.
- **BLE iOS** : les UUID GATT de la NETUM NT-1809DD doivent être validés via POC (tâche E3-1) avant de poursuivre E3-2+.
