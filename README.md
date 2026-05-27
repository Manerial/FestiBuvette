# LudoPay

Application mobile de caisse simplifiée avec impression thermique Bluetooth.
Fonctionne entièrement hors ligne (sauf connexion Bluetooth à l'imprimante).

**Stack :** Flutter 3.44 · Dart 3.12 · Riverpod · SQLite · ESC/POS

---

## Fonctionnalités

| Écran | Rôle |
|---|---|
| **Panier** | Sélectionner des produits avec quantités, calculer le total, imprimer |
| **Produits** | Gérer le catalogue (ajout, modification, suppression, réorganisation) |
| **Rapport** | Suivi journalier des ventes (CA, nb ventes, détail par produit) |
| **Imprimante** | Configurer la connexion Bluetooth à l'imprimante thermique |

---

## Architecture

```
lib/
├── main.dart                    Point d'entrée — initialise Riverpod
├── app.dart                     Coque : AppBar + Bottom Nav + IndexedStack
│
├── core/
│   ├── constants/               Constantes globales (nom app, clés prefs…)
│   ├── theme/                   Thème Material 3 (couleurs, styles)
│   └── database/                Singleton SQLite — création et migrations
│
├── shared/
│   ├── navigation/              Routes nommées (app_router)
│   └── widgets/                 Composants réutilisables (bottom nav bar)
│
└── features/
    ├── produits/                ✅ Complet
    │   ├── data/models/         Produit (immuable, copyWith, toMap/fromMap)
    │   ├── data/repositories/   ProduitsRepository — CRUD SQLite
    │   ├── providers/           ProduitsNotifier — état réactif Riverpod
    │   └── presentation/        ProduitsScreen + ProduitFormDialog
    │
    ├── panier/                  ✅ Complet
    │   ├── providers/           PanierNotifier — état en mémoire (Map id→qté)
    │   └── presentation/        PanierScreen
    │
    ├── ventes/                  ✅ Complet
    │   ├── data/models/         Vente, VenteLigne, Journee
    │   ├── data/repositories/   VentesRepository — accès SQLite
    │   └── services/            VenteService — orchestration d'une vente
    │
    ├── rapport/                 🔲 À implémenter (E4)
    └── imprimante/              🔲 À implémenter (E3)
```

---

## Flux d'une vente

```
Utilisateur sélectionne produits + quantités  (PanierScreen)
        ↓
Appuie sur [Imprimer]
        ↓
VenteService.enregistrer()
  ├── Récupère/crée la journée du jour (SQLite)
  ├── Insère la vente + toutes les lignes (transaction atomique)
  └── Met à jour CA et nb_ventes de la journée
        ↓
ImprimanteService.imprimer()  (E3 — Bluetooth ESC/POS)
        ↓
PanierNotifier.vider()  →  panier remis à zéro
```

---

## Base de données (SQLite local)

```sql
produits      (id, nom, prix_ttc, ordre, actif, cree_le)
journees      (id, date UNIQUE, ca_total, nb_ventes, cloturee_le)
ventes        (id, date_heure, total_ttc, journee_id)
ventes_lignes (id, vente_id, produit_id, nom_snapshot, prix_snapshot, quantite, sous_total)
```

> **Snapshot** : `nom_snapshot` et `prix_snapshot` sauvegardent le nom et le prix
> au moment de la vente. Si le prix change ensuite, l'historique reste cohérent.

> **Soft delete** : un produit déjà vendu passe à `actif = 0` plutôt que d'être
> supprimé physiquement, pour préserver l'intégrité de l'historique.

---

## Couches par feature

Chaque feature suit le même découpage :

| Couche | Rôle | Dépend de |
|---|---|---|
| `data/models/` | Définition des données (immuable) | Rien |
| `data/repositories/` | Accès SQLite brut | models + DatabaseHelper |
| `providers/` | Logique métier + état réactif | repositories |
| `presentation/` | Interface utilisateur | providers |

---

## Lancer le projet

```bash
flutter pub get
flutter run
```

> Nécessite Android Studio installé avec le SDK Android (API 33+).

---

## Générer l'APK

```bash
flutter build apk --split-per-abi
```

> Build iOS uniquement depuis macOS.

Apk dans build\app\outputs\flutter-apk\

| APK | Architecture | Taille | Usage |
|---|---|---|---|
|app-arm64-v8a-release.apk | Android récent 64-bit | 17.8 MB | 👈 ton téléphone (quasi certain) |
| app-armeabi-v7a-release.apk | Android ancien 32-bit | 15.4 MB | appareils < 2015 |
| app-x86_64-release.apk | Émulateur | 19.2 MB | tests sur émulateur |

---

## Backlog

Voir [BACKLOG.md](BACKLOG.md) pour le suivi des tâches.
