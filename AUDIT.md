# Audit — FestiBuvetteApp

_Date : 2026-05-28 — Branche : master_

---

## Légende

| Catégorie | Description |
|-----------|-------------|
| **BUG** | Comportement incorrect confirmé, reproductible |
| **RISQUE** | Pas de crash immédiat, mais peut provoquer des données erronées ou un plantage dans un cas précis |
| **ARCHI** | Violation des conventions définies dans CLAUDE.md |
| **TEXTE** | Contenu UI ou l10n incorrect / obsolète |

---

## BUG-1 — Agrégats `business_day` corrompus sur double-tap

**Fichier :** `lib/features/sales/services/sale_service.dart:46, 79-83`  
**Sévérité :** Élevée

`record()` lit le `businessDay` en début de méthode, insère la vente, puis recalcule les agrégats à partir des valeurs lues **avant** l'insertion :

```dart
// Lecture (ligne 46)
final businessDay = await _repo.getOrCreateToday(); // saleCount = N

// ... insert atomique ...

// Écriture (ligne 79) — valeur ABSOLUE calculée sur N
await _repo.updateBusinessDay(
  businessDay.id!,
  totalRevenue: businessDay.totalRevenue + total,  // N + total, pas N+1+total
  saleCount: businessDay.saleCount + 1,            // N+1, pas N+2
);
```

Si deux appels à `record()` sont lancés simultanément (double-tap sur le bouton "Enregistrer"), les deux lisent `saleCount = N`. Les deux ventes sont bien insérées (transaction atomique distincte pour chacune), mais les deux écrivent `saleCount = N+1` au lieu que la seconde écrive `N+2`. Résultat : une vente disparaît des agrégats du rapport.

À noter : `deleteSale` dans `SalesRepository` fait l'inverse correctement (recompute depuis la DB avec `SUM`/`COUNT`). L'asymétrie entre les deux est elle-même source de confusion.

**Fix :** Remplacer l'`update` absolu par un incrément SQL atomique :
```sql
UPDATE business_days
SET total_revenue = total_revenue + ?,
    sale_count    = sale_count + 1
WHERE id = ?
```

---

## BUG-2 — `late final _repo` dans les notifiers

**Fichiers :** `lib/features/products/providers/products_provider.dart:12`  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`lib/features/products/providers/categories_provider.dart:12`  
**Sévérité :** Élevée — **Corrigé dans cette session**

Riverpod 2 réutilise la même instance du notifier et rappelle `build()` à chaque `ref.invalidate()`. `late final` n'autorise qu'une seule assignation → `LateInitializationError` reproduit systématiquement après un import de catalogue.

Résolution : champ initialisé directement (`final _repo = Repository(DatabaseHelper.instance)`), sans passer par `build()`.

---

## BUG-3 — `getOrCreateToday()` crash sur appel concurrent en début de journée

**Fichier :** `lib/features/sales/data/repositories/sales_repository.dart:17-38`  
**Sévérité :** Moyenne — confirmé par test

`getOrCreateToday()` fait un SELECT puis un INSERT séparés (pattern check-then-act non atomique) :

```dart
final rows = await db.query('business_days', where: 'date = ?', ...);
if (rows.isNotEmpty) return BusinessDay.fromMap(rows.first);
// ← un second appel concurrent peut passer ici aussi
final id = await db.insert('business_days', {...}); // UNIQUE constraint violation
```

Si deux appels arrivent simultanément avant que la journée existe (premier tap de la journée avec double-tap), les deux voient `rows.isEmpty = true` et tentent d'insérer. Le second insert lève `DatabaseException: UNIQUE constraint failed: business_days.date`.

**Fix :** Utiliser `INSERT OR IGNORE` suivi d'un SELECT :
```sql
INSERT OR IGNORE INTO business_days (date, total_revenue, sale_count) VALUES (?, 0, 0);
SELECT * FROM business_days WHERE date = ?;
```

---

## RISQUE-1 — Double-tap sur "Enregistrer" non protégé

**Fichier :** `lib/features/cart/presentation/screens/cart_screen.dart:369-449`  
**Sévérité :** Moyenne

`_printAndRecord` ne possède pas de verrou (`_isProcessing`, `_isLoading`). La seule garde existante (`cartNotifier.isEmpty`, ligne 372) ne suffit pas : le panier n'est vidé qu'après le retour de `_recordSale` (ligne 355), donc un second tap pendant l'`await` passe la vérification et déclenche un second enregistrement concurrent.

Combiné à BUG-1, les deux ventes sont insérées mais les agrégats n'en comptent qu'une.

**Fix :** Ajouter un flag `bool _isRecording = false` avec `setState` autour de l'appel, ou désactiver le bouton pendant l'opération.

---

## RISQUE-2 — `PRAGMA foreign_keys = ON` absent

**Fichier :** `lib/core/database/database_helper.dart:16-25`  
**Sévérité :** Faible

SQLite n'applique pas les contraintes de clés étrangères sans ce pragma. Il n'y a pas de callback `onOpen` dans l'appel à `openDatabase`. Les tables `sales`, `sale_lines` et `products` déclarent des FK, mais aucune n'est vérifiée à l'exécution. Un bug dans la logique applicative (effacement de produit mal gardé, par exemple) pourrait créer des lignes orphelines sans erreur visible.

**Fix :**
```dart
return openDatabase(
  path,
  version: AppConstants.dbVersion,
  onCreate: _onCreate,
  onUpgrade: _onUpgrade,
  onOpen: (db) async => db.execute('PRAGMA foreign_keys = ON'),
);
```

---

## ARCHI-1 — `SaleService` instancié directement dans la présentation

**Fichier :** `lib/features/cart/presentation/screens/cart_screen.dart:351`  
**Sévérité :** Faible

```dart
await SaleService().record(...);
```

`SaleService` est instancié dans la couche présentation, en contournant les providers. Cela viole la règle « jamais de logique métier dans la présentation » et rend l'enregistrement de vente non testable par injection de provider.

**Fix :** Exposer un `saleServiceProvider` (ou intégrer `record()` dans un notifier dédié) et appeler `ref.read(saleServiceProvider).record(...)`.

---

## TEXTE-1 — Sous-titre export catalogue obsolète (FR)

**Fichier :** `lib/l10n/app_fr.arb:125`  
**Sévérité :** Faible

```json
"catalogueExportSubtitle": "Partager en JSON pour configurer un autre téléphone"
```

Depuis la correction de l'export (session courante), le comportement sur Android est un dialog de sauvegarde natif (`ACTION_CREATE_DOCUMENT`), pas un partage. La chaîne anglaise ("Share as a JSON file…") est dans le même cas.

**Fix :**
```json
// app_fr.arb
"catalogueExportSubtitle": "Exporter en JSON pour configurer un autre téléphone"
// app_en.arb
"catalogueExportSubtitle": "Export as a JSON file to configure another phone"
```

---

## Résumé

| ID | Catégorie | Titre | Sévérité | État |
|----|-----------|-------|----------|------|
| BUG-1 | BUG | Agrégats `business_day` corrompus sur double-tap | Élevée | **Résolu** |
| BUG-2 | BUG | `late final _repo` dans les notifiers | Élevée | **Résolu** |
| BUG-3 | BUG | `getOrCreateToday()` crash UNIQUE constraint sur appel concurrent | Moyenne | **Résolu** |
| RISQUE-1 | RISQUE | Double-tap sur "Enregistrer" non protégé | Moyenne | Ouvert |
| RISQUE-2 | RISQUE | `PRAGMA foreign_keys = ON` absent | Faible | **Résolu** |
| ARCHI-1 | ARCHI | `SaleService` instancié dans la présentation | Faible | Ouvert |
| TEXTE-1 | TEXTE | Sous-titre export catalogue obsolète | Faible | Ouvert |
