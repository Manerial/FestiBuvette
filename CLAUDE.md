# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Projet

**FestiBuvette** — application mobile de caisse simplifiée (Android + iOS).
Catalogue de produits (~20 articles), panier avec quantités, total, impression ticket de commande via imprimante thermique Bluetooth (NETUM NT-1809DD, protocole ESC/POS).
100 % hors ligne. Aucun backend. Aucune authentification.

**Contexte d'usage :** festival d'une journée. Le ticket imprimé est un **ticket de commande** : le caissier l'imprime et le donne au client, qui le remet lui-même à la buvette pour que sa commande soit préparée. Ce n'est pas un reçu client. Le rapport journalier suffit ; l'export CSV/PDF est la seule sortie de données envisagée.

**Flutter 3.44 · Dart 3.12 · Riverpod 2.6 · sqflite · intl · shared_preferences**

---

## Commandes essentielles

```bash
flutter pub get          # installer les dépendances
flutter analyze          # linter — doit retourner "No issues found"
flutter test             # tous les tests
flutter test test/widget_test.dart   # un test spécifique
flutter run              # lancer sur device/émulateur connecté
flutter build apk        # build Android
```

---

## Architecture

Chaque feature suit **4 couches strictes** dans cet ordre de dépendance :

```
data/models/       →  data/repositories/  →  providers/  →  presentation/
(données pures)       (accès SQLite)          (état réactif)  (UI)
```

Les couches inférieures ne connaissent jamais les couches supérieures.

**Features actuelles :**
- `products/` — CRUD catalogue, drag & drop, soft delete, catégories (filtre + gestion)
- `cart/` — état en mémoire (`CartState` : quantities + tenderedAmount), footer rétractable (swipe/tap), calculateur de monnaie
- `sales/` — modèles + repository + `SaleService` (transaction atomique)
- `report/` — navigation jour par jour, vue par produit (prix unitaire inclus) et par panier, clôture journée
- `printer/` — scan BT, connexion, déconnexion, auto-reconnexion, impression ESC/POS, test page · POC BLE iOS (GATT NETUM NT-1809DD) encore à valider en E3-1
- `settings/` — nom de l'établissement, langue (système / fr / en)

**Couches transverses :**
- `core/database/database_helper.dart` — singleton SQLite, schéma, migrations
- `core/theme/` — thème Material 3 centralisé
- `core/constants/` — constantes globales (noms, clés SharedPreferences)

---

## Règles

- **Toujours** clarifier au maximum la demande de l'utilisateur avant d'en faire une feature.
- **Toujours** alimenter le BACKLOG.md avant une nouvelle feature afin de planifier son développement.
- **Toujours** lire quelques fichiers de code avant de commencer afin de comprendre l'architecture, la structure et la façon de coder.
- **Toujours** coder en anglais : noms de classes, de méthodes, de champs, chaînes UI, commentaires.
- **Toujours** utiliser des chemins de package si possible — **jamais** de chemins relatifs (`../`) (exception pour les helpers de test (`test/helpers/`) car les fichiers `test/` ne sont pas accessibles via `package:`).
- **Toujours** mettre les noms de tables et colonnes SQL en anglais `snake_case`.
- **Toujours** vérifier si le code peut être factorisé de manière performante et intelligente.
- **Toujours** `flutter analyze` avant de tester une feature. Corriger les éléments remontés, zéro warning toléré.
- **Toujours** `flutter test` avant de livrer une feature. Une feature sans tests n'est pas considérée comme terminée.
- **Toujours** vérifier l'état du BACKLOG.md après la livraison d'une feature.
- **Toujours** faire des phrases de commit concises : `feat(products): [short description]`.
- **Toujours** faire un `flutter gen-l10n` après modification des ARB.
- **Jamais** de `String` en dur — toujours passer par `l10n`.
- **Jamais** de SQL sur les écrans `presentation/`, **toujours** passer par le provider.
- **Jamais** de _ devant un nom de variable. Le `flutter analyze` renverra une erreur.

---

## Conventions

**Nommage**
- Providers : `xxxProvider` + `XxxNotifier` dans le même fichier
- Repositories : accès brut SQLite, aucune logique métier
- Services (`sales/services/`) : orchestration multi-repository, logique métier complexe
- Widgets privés dans un écran : préfixés `_` (ex: `_ProductTile`)

**État (Riverpod)**
- État async (lecture BDD) → `AsyncNotifier` + `AsyncNotifierProvider`
- État synchrone en mémoire (panier) → `Notifier` + `NotifierProvider`
- Mise à jour optimiste : mettre à jour `state` avant d'attendre SQLite quand l'UI doit réagir immédiatement (ex: drag & drop)
- Pas de `StateProvider` ni `ChangeNotifier` — Riverpod 2 uniquement

**Base de données**
- `DatabaseHelper.instance` est le seul point d'entrée SQLite dans toute l'app
- Toujours utiliser `db.transaction()` pour les écritures multi-tables
- Tables : `categories`, `products`, `business_days`, `sales`, `sale_lines`
- `sale_lines` stocke `name_snapshot` et `price_snapshot` : ne jamais recalculer depuis les produits actuels
- `sort_order` (et non `order`) pour la colonne de tri des produits — `ORDER` est un mot-clé SQL réservé
- Schéma v2 : ajout de la table `categories` et colonne `category_id` (nullable FK) dans `products`

---

## Localisation (i18n)

L'app supporte **français** et **anglais** via `flutter_localizations` + `gen_l10n`.
La langue est détectée automatiquement depuis les paramètres du device. Fallback : anglais.

**Fichiers à modifier pour ajouter/modifier une chaîne :**
- `lib/l10n/app_en.arb` — chaîne anglaise + métadonnées (`@key` pour les `placeholders` uniquement)
- `lib/l10n/app_fr.arb` — traduction française (pas de `@key`, juste la valeur)

**Règles :**
- Les fichiers `app_localizations*.dart` sont générés : **ne pas les éditer à la main**
- Import : `import 'package:ludo_pay_app/l10n/app_localizations.dart';`
- Vérifier que les fichiers contiennent les clés dans le même ordre.

---

## Tests

**Ce qu'il faut couvrir par couche :**
- Repository : toutes les opérations CRUD + cas limites (soft delete, contraintes…) avec une BDD en mémoire via `sqflite_common_ffi`
- Notifier : toutes les transitions d'état (valeur initiale, chaque méthode publique)
- Service : logique métier (cas nominal + cas d'erreur)|

---

## Bluetooth (E3 — implémenté, POC iOS en attente)

L'imprimante cible est la **NETUM NT-1809DD** (BLE sur iOS, SPP Classic sur Android).
`PrinterService` / `PrinterNotifier` sont fonctionnels sur Android.
Avant de valider iOS (E3-1), confirmer les UUID GATT de l'imprimante avec l'app **nRF Connect**.
L'adresse BT est persistée dans `shared_preferences` (clé : `AppConstants.keyPrinterAddress`).
