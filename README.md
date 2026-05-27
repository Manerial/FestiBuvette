# FestiBuvette

Application mobile de caisse simplifiée avec impression thermique Bluetooth.
Fonctionne entièrement hors ligne (sauf connexion Bluetooth à l'imprimante).

**Stack :** Flutter 3.44 · Dart 3.12 · Riverpod 2.6 · SQLite · ESC/POS

---

## Fonctionnalités

| Écran | Rôle |
|---|---|
| **Panier** | Sélectionner des produits par catégorie, calculer le total, saisir le montant remis (rendu monnaie automatique), imprimer le ticket · Footer rétractable (swipe haut/bas) |
| **Produits** | Gérer le catalogue (ajout, modification, suppression, drag & drop) et les catégories (ajout, renommage, suppression, réorganisation) |
| **Rapport** | Historique jour par jour — CA, nb ventes, détail par produit (prix unitaire · quantité · sous-total) ou par panier (horodaté), clôture journée |
| **Imprimante** | Configurer la connexion Bluetooth (NETUM NT-1809DD ou compatible ESC/POS 58 mm) : scan, connexion, test page, auto-reconnexion |
| **Paramètres** | Nom de l'établissement (affiché dans l'app et sur les tickets), langue (système / fr / en) |

---

## Commandes essentielles

```bash
flutter pub get          # installer les dépendances
flutter analyze          # linter — doit retourner "No issues found"
flutter test             # tous les tests unitaires
flutter run              # lancer sur device/émulateur connecté
.\build_apk.ps1          # build Android + copie renommée dans APK/ (voir section APK)
flutter gen-l10n         # régénérer les fichiers de localisation après édition des .arb
```

---

## Architecture

```
lib/
├── main.dart                        Point d'entrée — initialise Riverpod + localisation
├── app.dart                         Coque : AppBar + Bottom Nav + IndexedStack
│
├── core/
│   ├── constants/app_constants.dart Constantes globales (nom app par défaut, clés SharedPrefs)
│   ├── theme/                       Thème Material 3 centralisé
│   ├── database/database_helper.dart Singleton SQLite — schéma, migrations
│   └── services/bluetooth_permissions.dart  Abstraction permissions BT (testable)
│
├── l10n/
│   ├── app_en.arb                   Chaînes anglaises + métadonnées (@key)
│   ├── app_fr.arb                   Traductions françaises
│   └── app_localizations*.dart      ⚠ Généré — ne pas éditer à la main
│
└── features/
    ├── products/                    ✅ Complet
    │   ├── data/models/             Product + Category (immuables, copyWith, toMap/fromMap)
    │   ├── data/repositories/       ProductsRepository + CategoriesRepository — CRUD SQLite
    │   ├── providers/               ProductsNotifier + CategoriesNotifier — listes réactives Riverpod
    │   └── presentation/            ProductsScreen + ProductFormDialog + CategoryFormDialog + CategoryFilterBar
    │
    ├── cart/                        ✅ Complet
    │   ├── providers/               CartNotifier — CartState en mémoire (quantities + tenderedAmount)
    │   └── presentation/            CartScreen + _Footer rétractable (_TotalRow + _TenderedRow + _ActionRow)
    │
    ├── sales/                       ✅ Complet
    │   ├── data/models/             Sale, SaleLine, BusinessDay
    │   ├── data/repositories/       SalesRepository — accès SQLite
    │   └── services/                SaleService — orchestration transaction atomique
    │
    ├── report/                      ✅ Complet
    │   ├── providers/               ReportNotifier — navigation jour par jour
    │   └── presentation/            ReportScreen (_SummaryCard, _ProductView, _CartView)
    │
    ├── printer/                     ✅ Complet (POC BLE iOS à valider — E3-1)
    │   ├── data/models/             PrinterDevice
    │   ├── data/services/           PrinterService (BT), TicketService (ESC/POS)
    │   ├── providers/               PrinterNotifier
    │   └── presentation/            PrinterScreen
    │
    └── settings/                    ✅ Complet
        └── providers/               SettingsNotifier (appName + locale)
```

---

## Flux d'une vente

```
Utilisateur sélectionne produits + quantités  (CartScreen)
        ↓
Appuie sur [Imprimer]
        ↓
Imprimante connectée ?
  ├── Non → dialog : "Enregistrer sans imprimer ?" ou Annuler
  └── Oui → TicketService.buildReceiptFromCart()
               └── PrinterNotifier.printBytes()
                     ├── Échec → snackbar erreur, vente NON enregistrée
                     └── Succès ↓
        ↓
SaleService.record()
  ├── Récupère / crée la journée du jour (business_days)
  ├── Insère la vente + toutes les lignes (transaction atomique)
  └── Met à jour total_revenue et sale_count de la journée
        ↓
CartNotifier.clear()  →  panier remis à zéro + snackbar ✅
```

---

## Base de données (SQLite local)

```sql
categories    (id, name, sort_order)
products      (id, name, price, sort_order, active, created_at, category_id → categories)
business_days (id, date UNIQUE, total_revenue, sale_count, closed_at)
sales         (id, date_time, total, business_day_id → business_days)
sale_lines    (id, sale_id, product_id, name_snapshot, price_snapshot, quantity, subtotal)
```

> **Schéma v2** : ajout de la table `categories` et de la colonne `category_id` (nullable) dans `products`.

> **Snapshot** : `name_snapshot` et `price_snapshot` sauvegardent le nom et le prix
> au moment de la vente. Les modifications ultérieures de prix ne touchent pas l'historique.

> **Soft delete** : un produit déjà vendu passe à `active = 0` (masqué dans le catalogue
> et le panier) plutôt qu'être supprimé physiquement, pour préserver l'intégrité de l'historique.

---

## Modifier le nom de l'application

Il y a **trois niveaux** de nommage, indépendants :

### 1. Nom affiché sur les tickets et dans l'app (en production)

Réglable directement dans l'appli : **Paramètres → Nom de l'établissement**.
Modifiable à tout moment, persisté en local (`SharedPreferences`).

### 2. Nom par défaut dans le code (fallback si aucun nom saisi)

```dart
// lib/core/constants/app_constants.dart
static const String appName = 'FestiBuvette';   // ← modifier ici
```

### 3. Nom de l'icône sur l'écran d'accueil (launcher label)

**Android** — `android/app/src/main/AndroidManifest.xml` :
```xml
<application android:label="FestiBuvette" ...>
```

**iOS** — `ios/Runner/Info.plist` :
```xml
<key>CFBundleDisplayName</key>
<string>FestiBuvette</string>
```

### 4. Nom du fichier APK généré

```powershell
# build_apk.ps1 — table $renames
"app-arm64-v8a-release.apk"   = "FestiBuvette_64.apk"    # ← modifier le préfixe ici
"app-armeabi-v7a-release.apk" = "FestiBuvette_32.apk"
"app-x86_64-release.apk"      = "FestiBuvette_x86_64.apk"
```

---

## Générer l'APK Android

```powershell
.\build_apk.ps1
```

Le script build les APKs, puis les copie renommés dans `APK/` à la racine du projet (gitignoré) :

| Fichier | Architecture | Taille | Usage |
|---|---|---|---|
| `FestiBuvette_64.apk` | arm64-v8a — Android récent 64-bit | ~17.8 MB | 👈 quasi tous les téléphones actuels |
| `FestiBuvette_32.apk` | armeabi-v7a — Android ancien 32-bit | ~15.4 MB | appareils antérieurs à 2015 |
| `FestiBuvette_x86_64.apk` | x86_64 — émulateur | ~19.2 MB | tests sur émulateur Android Studio |

> **iOS** : build uniquement depuis macOS (`flutter build ios`).

---

## Localisation (i18n)

L'app supporte **français** et **anglais**. Pour ajouter ou modifier une chaîne :

1. Éditer `lib/l10n/app_en.arb` (chaîne + `@key` avec description et placeholders)
2. Éditer `lib/l10n/app_fr.arb` (traduction, sans `@key`)
3. Régénérer : `flutter gen-l10n`

Ne jamais éditer les fichiers `app_localizations*.dart` à la main (générés automatiquement).

---

## Tests

```bash
flutter test                                   # tous les tests
flutter test test/features/report/             # un dossier spécifique
```

Couverture par couche : repositories (SQLite in-memory via `sqflite_common_ffi`),
notifiers (transitions d'état), services (logique métier).

---

## Backlog

Voir [BACKLOG.md](BACKLOG.md) pour le suivi des tâches et l'état d'avancement.
