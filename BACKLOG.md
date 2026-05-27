# Backlog — FestiBuvetteApp

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
  - `flutter_riverpod 2.6.1`, `sqflite 2.4.2`, `path 1.9.1`, `intl 0.20.2`, `shared_preferences 2.5.3`, `permission_handler 11.3.0`
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
- [x] **E3-8** Runtime Bluetooth permissions
  - Android 12+: `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` via `permission_handler`
  - iOS: `NSBluetooth` permission
  - `BluetoothPermissions` abstract class (injected into `PrinterNotifier` for testability)
  - Silent check on launch; prompt on scan/connect; "Open Settings" button if denied

---

## EPIC 4 — Daily report

- [x] **E4-1** Aggregated SQLite queries: daily revenue, sale count, qty by product
  - `getTotalsByProduct()` — GROUP BY product, sorted by qty DESC
  - `getSalesWithLinesByDay()` — 2-query pattern (no N+1)
  - `getAllBusinessDays()` — all days ORDER BY date DESC
- [x] **E4-2** Riverpod `ReportNotifier`
  - `_load([index])` — parallel fetch of totals + sales via `Future.wait`
  - `goToPreviousDay()` / `goToNextDay()` — silent navigation (no full-screen spinner)
  - `closeDay()` / `refresh()` — preserve current day index across reloads
- [x] **E4-3** Report screen:
  - `_SummaryCard`: navigation arrows ← date →, revenue, sale count, `_ClosedBadge` / `_CloseDayButton`
  - `SegmentedButton` to switch between "By product" and "By cart" views
- [x] **E4-4** "By product" view — product totals (name × qty → amount), sorted by qty desc
- [x] **E4-5** "By cart" view — chronological list of sales (time + total header, lines expanded inline)
- [x] **E4-10** "By hour" view — grouped bar chart 9h–18h, one series per product, multi-select filter; `fl_chart 0.69`
- [x] **E4-8** "By cart" view — delete a sale (confirmation dialog, cascade delete lines, recalc business day aggregates)
- [x] **E4-9** "By cart" view — reprint receipt from a past sale (`buildReceiptFromSale` via snapshots)
- [x] **E4-6** "Close day" button: confirmation dialog + archive (`closed_at = NOW`)
- [x] **E4-7** Day-by-day history navigation (← → arrows in summary card; `canGoPrevious` / `canGoNext` guards)

---

## EPIC 5 — Quality & finalization

- [x] **E5-1** Form validation (name required, price > 0, numeric format)
- [x] **E5-2** Empty states (empty product list → message + CTA, empty cart → message, no sales today → message)
- [x] **E5-3** Configurable business name (settings screen + printed on receipt)
- [x] **E5-4** App icon (Android + iOS)
- [x] **E5-6** Test on physical Android device (APK installed, core flows validated)
- [x] **E5-8** Android build — `flutter build apk --split-per-abi` → arm64-v8a 17.8 MB
- [x] **E5-10** In-app language switcher (system / français / English) in settings screen
- [x] **E5-11** Widget refactoring — high priority extractions:
  - `report_screen.dart`: `_SummaryCard`, `_ReportLineRow` (deduplicates product & cart rows)
  - `cart_screen.dart`: `_TotalRow`, `_ActionRow`
- [x] **E5-12** Unit price displayed in report "By product" view (price_snapshot · qty · subtotal)

---

## EPIC 6 — Product categories

- [x] **E6-1** `Category` model + `categories` SQLite table (DB migration v1→v2)
- [x] **E6-2** `CategoriesRepository` — CRUD (insert, getAll, update, delete + uncategorize products)
- [x] **E6-3** Riverpod `CategoriesNotifier` — reactive list
- [x] **E6-4** `category_id` (nullable FK) added to `products` table and `Product` model
- [x] **E6-5** `CategoryFilterBar` shared widget — filter chips (All + per category), optional manage button
- [x] **E6-6** Products screen — filter bar + category management bottom sheet (add / rename / delete)
- [x] **E6-7** Product form dialog — category dropdown (optional, defaults to current filter)
- [x] **E6-8** Cart screen — category filter chips to quickly find products
- [x] **E6-9** i18n strings (EN + FR)
- [x] **E6-10** Tests: `CategoriesRepository` (CRUD + delete-uncategorizes)

---

## EPIC 7 — Change calculator

- [x] **E7-1** `CartState` wrapper — holds `quantities` map + optional `tenderedAmount`
- [x] **E7-2** `CartNotifier.setTenderedAmount()` — real-time change computation (`tendered − total`)
- [x] **E7-3** Block sale confirmation if tendered amount is set but less than total
- [x] **E7-4** `_TenderedRow` widget — numeric input + change display (hidden if tendered < total)
- [x] **E7-5** i18n strings (EN + FR): `tenderedAmount`, `changeDue`, `insufficientAmount`
- [x] **E7-6** Tests: `CartNotifier` — change computation + edge cases (exact, overpay, underpay)

---

## EPIC 8 — UX & polish

- [x] **E8-1** Collapsible cart footer — drag handle + total always visible, swipe up/down or tap to expand (`AnimatedAlign` + `heightFactor`, widget stays in tree)
- [x] **E8-2** AppBar orange (#FFA946), no tint on scroll (`scrolledUnderElevation: 0`, `surfaceTintColor: transparent`, `systemOverlayStyle`)
- [x] **E8-3** Bottom nav selected color aligned with `colorScheme.primary` (was hardcoded seed value)
- [x] **E8-4** Product grid view — large tap tiles as alternative to list in cart screen (toggle in toolbar, preference persisted in SharedPreferences); easier to use with large fingers or outdoor conditions
- [x] **E8-5** End-of-day report — daily summary (revenue, sale count, breakdown by product and by cart) with day close; covered by E4 report screen
- [x] **E8-6** Cancel last sale — delete any sale from "By cart" view with confirmation dialog + business day aggregate recompute (E4-8)
- [x] **E8-7** Reprint last ticket — reprint any past sale from "By cart" view using ESC/POS snapshots (E4-9)

---

## Suggested iteration order

```
Iteration 1 — Skeleton & data          ✅ done
  E0 → E1 → E2

Iteration 2 — Cart & report (no print) ✅ done
  E4 → E5 (non-Bluetooth items)
  → App is already usable without printing

Iteration 3 — Bluetooth printing       ✅ done (pending E3-1 POC on device)
  E3-1 (POC) → E3-2 to E3-8
  → Validate BLE on iOS first

Iteration 4 — Polish                   🔲 in progress
  E999 (statistics + iOS/BLE — deferred)
```

---

## EPIC 9 — Statistics

- [x] **E9-1** Hourly breakdown by product (peak hours chart) — grouped bar chart 9h–18h with multi-select filter (E4-10)

---

## EPIC 999 — Deferred (requires Mac / low priority)

- [ ] **E999-1** POC BLE iOS — scan, connect to NETUM NT-1809DD, identify GATT UUIDs via nRF Connect _(requires Mac + physical iOS device)_
- [ ] **E999-2** Bluetooth error handling (connection loss during print) — blocked on E999-1
- [ ] **E999-3** Test on physical iOS device (BLE validation) _(requires Mac)_
- [ ] **E999-4** iOS build (`.ipa`) _(requires Mac)_

---

## Technical notes

- **Price/name snapshot**: `sale_lines` stores name and price at time of sale. Later price changes do not alter history.
- **Product delete**: if `sale_lines` reference the product → `active = 0` (hidden from cart and list) instead of `DELETE`.
- **Current business day**: determined by `DATE('now')`. Auto-created if absent on first use of the day.
- **BLE iOS**: GATT UUIDs of the NETUM NT-1809DD must be validated via POC (E3-1) before proceeding with E5-5.
- **APK size**: `--split-per-abi` mandatory — fat APK ≈ 50 MB, arm64-v8a split ≈ 17.8 MB.
- **Bluetooth permissions**: `BluetoothPermissions` interface (injected) keeps `PrinterNotifier` testable without mocking `permission_handler` directly.
