# Backlog — LudoPayApp

> Flutter mobile app (Android + iOS) — simplified POS with Bluetooth thermal printing.
> All data stored locally (SQLite). Zero network dependency.

---

## Legend

| Status | Symbol |
|---|---|
| To do | `[ ]` |
| In progress | `[~]` |
| Done | `[x]` |
| Blocked | `[!]` |

---

## EPIC 0 — Project setup

- [x] **E0-1** Create Flutter project (`flutter create --org com.jcbpartner --platforms android,ios`)
- [x] **E0-2** Configure `pubspec.yaml` dependencies
  - `flutter_riverpod 2.6.1`, `sqflite 2.4.2`, `path 1.9.1`, `intl 0.20.2`, `shared_preferences 2.5.3`
  - _(Bluetooth printing: deferred to E3 after POC)_
- [x] **E0-3** Folder architecture (`features/`, `core/`, `shared/`)
- [x] **E0-4** SQLite database init (schema: `products`, `business_days`, `sales`, `sale_lines`)
- [x] **E0-5** Navigation (3-tab bottom nav bar + settings screen via AppBar icon)
- [x] **E0-6** AndroidManifest permissions (Bluetooth Classic + BLE, Android 12+ and legacy)
- [x] **E0-7** iOS Info.plist permissions (`NSBluetoothAlwaysUsageDescription`)
- [x] **E0-8** i18n: EN + FR via `flutter_localizations` + `gen_l10n`

---

## EPIC 1 — Product catalogue

- [x] **E1-1** `Product` model + SQLite repository (CRUD + `sort_order` field)
- [x] **E1-2** Riverpod `ProductsNotifier` (reactive list)
- [x] **E1-3** Products list screen (name + price display)
- [x] **E1-4** Drag & drop to reorder (`onReorderItem`, batch save)
- [x] **E1-5** "Add product" dialog (name + price, validation)
- [x] **E1-6** "Edit product" dialog (pre-filled, shared component)
- [x] **E1-7** Swipe left → delete with confirmation dialog
  - Rule: if product appears in past sales → deactivate (`active = 0`) instead of physical delete

---

## EPIC 2 — Cart & sale recording

- [x] **E2-1** Cart model (local `Map<id, qty>` state, not persisted)
- [x] **E2-2** Riverpod `CartNotifier` (increment, decrement, clear, calculateTotal)
- [x] **E2-3** Cart screen: product list with `[-]` / `[+]` buttons
- [x] **E2-4** Running total display at the bottom (real-time)
- [x] **E2-5** "Clear cart" button with confirmation dialog
- [x] **E2-6** Models `Sale` + `SaleLine` + `BusinessDay` + `SalesRepository`
- [x] **E2-7** Business day management: `getOrCreateToday()` automatic
- [x] **E2-8** `SaleService.record()` — atomic SQLite transaction + business day aggregates update

---

## EPIC 3 — Bluetooth thermal printing

- [!] **E3-1** POC: BLE scan, connect to NETUM NT-1809DD, identify GATT UUIDs — validate with nRF Connect on physical device
- [x] **E3-2** `PrinterService`: scan, connect, disconnect, persist device choice
- [x] **E3-3** Printer settings screen (BT device list, scan button, connection status)
- [x] **E3-4** "Test print" button (print a test receipt)
- [x] **E3-5** Auto-reconnect on launch if a printer is saved
- [x] **E3-6** `TicketService`: ESC/POS receipt formatting
  - Header (business name, date, time)
  - Product lines (name × qty → subtotal)
  - Separators, total, footer ("Thank you!"), paper cut
  - Note: prices formatted as `1,50 EUR` (ESC/POS Latin-1 encoding, `€` unsupported)
- [x] **E3-7** Full "Print" button flow:
  - Check cart not empty
  - Check printer connected (else: dialog → record only or cancel)
  - Print receipt
  - Record sale (`SaleService`)
  - Clear cart
  - Confirmation snackbar

---

## EPIC 4 — Daily report

- [x] **E4-1** Aggregated SQLite queries: daily revenue, sale count, qty by product
- [x] **E4-2** Riverpod `ReportNotifier`
- [x] **E4-3** Report screen:
  - Header: today's date, total revenue, sale count
  - "By product" section: name × qty → product total, sorted by qty desc
- [ ] **E4-4** "Sales history" section: chronological list (time + total)
- [ ] **E4-5** Tap a sale → bottom sheet with line details
- [x] **E4-6** "Close day" button: confirmation dialog + archive (`closed_at = NOW`)

---

## EPIC 5 — Quality & finalization

- [x] **E5-1** Form validation (name required, price > 0, numeric format)
- [x] **E5-2** Empty states (empty product list → message + CTA, empty cart → message, no sales today → message)
- [ ] **E5-3** Configurable business name (app bar + receipt)
- [ ] **E5-4** App icon (Android + iOS)
- [!] **E5-5** Bluetooth error handling (connection loss during print) — blocked on E3
- [ ] **E5-6** Test on physical Android device
- [ ] **E5-7** Test on physical iOS device (BLE validation)
- [ ] **E5-8** Android build (`.apk` / `.aab`)
- [ ] **E5-9** iOS build (`.ipa`)

---

## Suggested iteration order

```
Iteration 1 — Skeleton & data
  E0 → E1 → E2

Iteration 2 — Cart & report (no printing)
  E4 → E5 (non-Bluetooth items)
  → App is already usable without printing

Iteration 3 — Bluetooth printing
  E3-1 (POC) → E3-2 to E3-7
  → Validate BLE on iOS first

Iteration 4 — Polish
  E4-4, E4-5, remaining E5
```

---

## Technical notes

- **Price/name snapshot**: `sale_lines` stores name and price at time of sale. Later price changes do not alter history.
- **Product delete**: if `sale_lines` reference the product → `active = 0` (hidden from cart and list) instead of `DELETE`.
- **Current business day**: determined by `DATE('now')`. Auto-created if absent on first use of the day.
- **BLE iOS**: GATT UUIDs of the NETUM NT-1809DD must be validated via POC (E3-1) before proceeding with E3-2+.
