# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

## Projet

**LudoPay** — application mobile de caisse simplifiée (Android + iOS).
Catalogue de produits, panier avec quantités, total, impression ticket via imprimante thermique Bluetooth (NETUM NT-1809DD, protocole ESC/POS).
100 % hors ligne. Aucun backend. Aucune authentification.

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

> `flutter analyze` est obligatoire avant tout commit. Zéro warning toléré.

---

## Architecture

Chaque feature suit **4 couches strictes** dans cet ordre de dépendance :

```
data/models/       →  data/repositories/  →  providers/  →  presentation/
(données pures)       (accès SQLite)          (état réactif)  (UI)
```

Les couches inférieures ne connaissent jamais les couches supérieures.
Les écrans (`presentation/`) ne font **jamais** de SQL — ils passent toujours par le provider.

**Features actuelles :**
- `products/` — CRUD catalogue, drag & drop, soft delete
- `cart/` — état en mémoire (`Map<productId, quantity>`), non persisté
- `sales/` — modèles + repository + `SaleService` (transaction atomique)
- `report/` — 🔲 à implémenter (E4)
- `printer/` — 🔲 à implémenter (E3, Bluetooth BLE)

**Couches transverses :**
- `core/database/database_helper.dart` — singleton SQLite, schéma, migrations
- `core/theme/` — thème Material 3 centralisé
- `core/constants/` — constantes globales (noms, clés SharedPreferences)

---

## Conventions

**Langue du code**
- Tout le code Dart doit être en anglais : noms de classes, de méthodes, de champs, chaînes UI, commentaires.
- Les noms de tables et colonnes SQL sont également en anglais `snake_case`.

**Nommage**
- Providers : `xxxProvider` + `XxxNotifier` dans le même fichier
- Repositories : accès brut SQLite, aucune logique métier
- Services (`ventes/services/`) : orchestration multi-repository, logique métier complexe
- Widgets privés dans un écran : préfixés `_` (ex: `_ProduitTile`)

**État (Riverpod)**
- État async (lecture BDD) → `AsyncNotifier` + `AsyncNotifierProvider`
- État synchrone en mémoire (panier) → `Notifier` + `NotifierProvider`
- Mise à jour optimiste : mettre à jour `state` avant d'attendre SQLite quand l'UI doit réagir immédiatement (ex: drag & drop)
- Pas de `StateProvider` ni `ChangeNotifier` — Riverpod 2 uniquement

**Base de données**
- `DatabaseHelper.instance` est le seul point d'entrée SQLite dans toute l'app
- Toujours utiliser `db.transaction()` pour les écritures multi-tables
- Les colonnes SQL gardent le style `snake_case` ; les champs Dart sont en `camelCase`
- `ventes_lignes` stocke `nom_snapshot` et `prix_snapshot` : ne jamais recalculer depuis les produits actuels

**Suppression produit** : si `ventes_lignes` référence le produit → `actif = 0` (soft delete), sinon `DELETE` physique.

**Journée** : `SalesRepository.getOrCreateToday()` est le seul endroit qui crée une journée. Ne jamais insérer dans `journees` ailleurs.

**API Flutter**
- `onReorderItem` (pas `onReorder`, déprécié depuis Flutter 3.41) — l'index est déjà ajusté, ne pas faire `newIndex--`
- `AsyncNotifier` : ne pas nommer une méthode `update` (conflit avec `AsyncNotifierBase.update`)
- `withValues(alpha: x)` à la place de `withOpacity(x)` (déprécié Flutter 3.44)

---

## Localisation (i18n)

L'app supporte **français** et **anglais** via `flutter_localizations` + `gen_l10n`.
La langue est détectée automatiquement depuis les paramètres du device. Fallback : anglais.

**Fichiers à modifier pour ajouter/modifier une chaîne :**
- `lib/l10n/app_en.arb` — chaîne anglaise + métadonnées (`@key` avec `description` et `placeholders`)
- `lib/l10n/app_fr.arb` — traduction française (pas de `@key`, juste la valeur)

**Après modification des ARB :**
```bash
flutter gen-l10n   # régénère lib/l10n/app_localizations*.dart
```

**Utilisation dans un widget :**
```dart
// En haut de build()
final l10n = AppLocalizations.of(context)!;

// Chaîne simple
Text(l10n.cartTab)

// Chaîne avec paramètre
Text(l10n.errorMessage(e))          // {message} : Object
Text(l10n.deleteProductMessage(name)) // {name} : String
Text(l10n.maximumCharacters(50))    // {count} : int
```

**Règles :**
- Ne jamais mettre de `String` en dur dans les widgets — toujours passer par `l10n`
- Les fichiers `app_localizations*.dart` sont générés : **ne pas les éditer à la main**
- Import : `import 'package:ludo_pay_app/l10n/app_localizations.dart';`

---

## Tests

Fichier existant : `test/widget_test.dart` (smoke test).

**Tests obligatoires pour chaque feature :**
- Repository : tester les opérations CRUD avec une BDD en mémoire (`sqflite_common_ffi`)
- Service : tester la logique métier (ex: `SaleService.record` avec panier vide doit lever une exception)
- Notifier : tester les transitions d'état

Lancer un test isolé :
```bash
flutter test test/widget_test.dart
```

---

## Bluetooth (E3 — pas encore implémenté)

L'imprimante cible est la **NETUM NT-1809DD** (BLE sur iOS, SPP Classic sur Android).
Les packages d'impression sont commentés dans `pubspec.yaml` en attente du POC BLE (E3-1).
Avant d'implémenter E3, valider les UUID GATT de l'imprimante avec l'app **nRF Connect**.
L'`ImprimanteService` doit persister l'adresse BT dans `shared_preferences` (clé : `AppConstants.keyPrinterAddress`).
