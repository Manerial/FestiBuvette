# EPIC E11 — Multi-device sync

> **Status:** Planned — not yet started
> **Scope:** Android only (iOS BLE constraints are unrelated to this epic)

---

## Table of contents

1. [Context & goals](#1-context--goals)
2. [Architecture overview](#2-architecture-overview)
3. [Key design decisions](#3-key-design-decisions)
4. [Network & security](#4-network--security)
5. [HTTP API reference](#5-http-api-reference)
6. [New packages](#6-new-packages)
7. [Feature folder structure](#7-feature-folder-structure)
8. [Phase 1 — Day lifecycle](#8-phase-1--day-lifecycle)
9. [Phase 2 — Basic connectivity](#9-phase-2--basic-connectivity)
10. [Phase 3 — Real-time sync](#10-phase-3--real-time-sync)
11. [Legend](#11-legend)

---

## 1. Context & goals

FestiBuvette currently runs in standalone mode on a single device.
This epic adds support for running **multiple devices simultaneously** during a festival service
— one acting as the central hub ("control"), the others as point-of-sale terminals ("seconds").

The epic is split into three independent phases that can be delivered and tested separately.

### Roles

| Role | Quantity | Responsibilities |
|---|---|---|
| **Control** | 1 | HTTP server · Bluetooth printer · report · day management · data authority |
| **Second** | 1–5 | Cart composition · sale submission · local report (read-only) |
| **Standalone** | — | Current behavior, unchanged — single device, no network |

### Day states

| State | Sales | Catalog editing |
|---|---|---|
| **Not started** | Blocked | Allowed |
| **In progress** | Allowed | Blocked |
| **Closed** | Blocked | Allowed |

---

## 2. Architecture overview

```
┌─────────────────────────────────────────────────────────────┐
│                  WiFi network (hotspot or venue)            │
│                                                             │
│   ┌─────────────────────────┐                               │
│   │   CONTROL PHONE         │  ← recommended: screen off,   │
│   │                         │    plugged in                 │
│   │  shelf HTTP server :8080│                               │
│   │  mDNS: _festibuvette    │  → thermal printer            │
│   │  SQLite (authoritative) │                               │
│   │  Bluetooth printer      │                               │
│   └────────────┬────────────┘                               │
│                │  HTTP (REST/JSON)                          │
│       ┌────────┴────────┐                                   │
│       ▼                 ▼                                   │
│  ┌─────────┐       ┌─────────┐                              │
│  │ SECOND 1│       │ SECOND 2│  (up to 5 seconds)           │
│  │ SQLite  │       │ SQLite  │  ← full local copy           │
│  │ (mirror)│       │ (mirror)│                              │
│  └─────────┘       └─────────┘                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Key design decisions

### Phase-based delivery

- **Phase 1** is purely standalone: day lifecycle management, no networking. Unblocks phases 2 and 3.
- **Phase 2** adds basic HTTP connectivity: print delegation and manual end-of-day sales sync.
- **Phase 3** adds real-time sync via WebSocket: live sale broadcast, day start/close propagation.

### Day must be explicitly started

Before Phase 1, `BusinessDay` was created automatically on the first sale. After Phase 1, the operator must press "Start day" explicitly before any sale is possible. This gives full control over when the service begins and ensures the catalog is locked before the first transaction.

### WiFi over Bluetooth for sync

Bluetooth is used exclusively for the printer. WiFi handles all inter-device data sync.

### Control phone creates the WiFi hotspot (recommended setup)

No external infrastructure needed. The control phone creates an Android WiFi hotspot; seconds connect to it.
The control phone's IP on its own hotspot is almost always `192.168.43.1` on Android.
Venue WiFi is a valid alternative if reliable.

### mDNS for device discovery, manual IP as fallback

The control phone announces itself via mDNS (`_festibuvette._tcp`). Seconds find it automatically without any IP configuration. A manual IP field is available in settings as a fallback (pre-filled with `192.168.43.1`).

### Phase 2 sync is manual, not automatic

In Phase 2, there is no real-time sync. Each device manages its own day independently.
Sales sync is triggered manually by the operator at end of day:
1. Each second sends its sales to the control ("Send sales").
2. The control aggregates all received sales into its SQLite.
3. Each second can then download the full aggregated view ("Download sales").

### Phase 3 uses WebSocket for push notifications

In Phase 3, the control maintains a WebSocket connection with each second.
The control pushes notifications (sale recorded, day started, day closed) to all connected seconds.
Seconds apply each notification to their local SQLite immediately.
Sale submission (DB update) and print request remain two separate HTTP calls.

---

## 4. Network & security

### PIN authentication

The control phone generates a **6-digit PIN** (displayed in its settings). Each second must enter this PIN once when connecting for the first time. The PIN is used to derive an auth token stored in `SharedPreferences` on the second.

Every HTTP request from a second includes the token in the `Authorization` header:
```
Authorization: Bearer <token>
```

The control server rejects any request with a missing or invalid token with `401 Unauthorized`.

### No HTTPS required

Traffic stays on a local network. Plain HTTP is acceptable.

---

## 5. HTTP API reference

All endpoints require `Authorization: Bearer <token>` except `/auth`.

### Authentication (Phase 2)

```
POST /auth
Body: { "pin": "123456" }
Response 200: { "token": "<uuid>" }
Response 401: { "error": "invalid_pin" }
```

### Catalog sync (Phase 2)

```
GET /sync/catalog
Response 200: {
  "products": [...],
  "categories": [...]
}
```

### Print request (Phase 2)

```
POST /print
Body: {
  "items": [
    { "product_id": 1, "name": "...", "price": 2.50, "quantity": 2 }
  ]
}
Response 200: { "ok": true }
Response 503: { "error": "print_failed" }
```

> The second sends name + price snapshots directly — the control does not resolve products.
> The control prints only; it does not record the sale.

### Sales push — second → control (Phase 2)

```
POST /sales/push
Body: {
  "sales": [
    {
      "local_id": 42,
      "date_time": "...",
      "total": 7.50,
      "lines": [
        { "name_snapshot": "...", "price_snapshot": 2.50, "quantity": 2 }
      ]
    }
  ]
}
Response 200: { "merged": 3 }
```

> Only available after the day is closed. The control merges received sales, skipping duplicates.

### Sales pull — second ← control (Phase 2)

```
GET /sales/pull
Response 200: {
  "sales": [...],
  "sale_lines": [...]
}
```

> Returns all sales for the current business day (from all devices).

### Server status  (Phase 2)

```
GET /status
Response 200: {
  "role": "control",
  "day_started": true,
  "connected_seconds": 2
}
```

### WebSocket (Phase 3)

```
WS /ws
```

Messages pushed by control to seconds (JSON):

```json
{ "type": "day_started", "payload": { "business_day_id": 5 } }
{ "type": "day_closed",  "payload": { "business_day_id": 5 } }
{ "type": "sale_added",  "payload": { "sale": {...}, "sale_lines": [...] } }
```

### Sale notify — second → control (Phase 3)

```
POST /sales/notify
Body: {
  "local_id": 42,
  "date_time": "...",
  "total": 7.50,
  "lines": [...]
}
Response 200: { "ok": true }
```

> Control records the sale in its SQLite and broadcasts a `sale_added` WebSocket message to all
> other connected seconds. Separate from the print request.

---

## 6. New packages

| Package | Phase | Role | Used by |
|---|---|---|---|
| `shelf` | P2 | HTTP server framework | Control |
| `shelf_router` | P2 | Route definitions for shelf | Control |
| `shelf_web_socket` | P3 | WebSocket support for shelf | Control |
| `multicast_dns` | P2 | mDNS announcement + discovery | Control + Second |
| `http` | P2 | HTTP client | Second |
| `web_socket_channel` | P3 | WebSocket client | Second |
| `flutter_foreground_task` | P2 | Android Foreground Service + WakeLock | Control |

> **Note:** `http` may already be a transitive dependency. Check `pubspec.lock` before adding it explicitly.

---

## 7. Feature folder structure

```
lib/features/sync/
├── data/
│   ├── models/
│   │   ├── sync_role.dart          enum SyncRole { standalone, control, second }
│   │   └── connected_device.dart   ConnectedDevice (ip, token, connectedAt)
│   └── services/
│       ├── sync_server.dart        shelf HTTP + WS server — control only
│       ├── sync_client.dart        HTTP + WS client wrapper — second only
│       └── mdns_service.dart       mDNS announce (control) + discover (second)
├── providers/
│   └── sync_provider.dart          SyncNotifier + SyncState
│                                   state: role · connectionStatus · connectedDevices
└── presentation/
    └── widgets/
        ├── connection_status_icon.dart   AppBar icon (hidden in standalone)
        └── sync_settings_section.dart    Section in the settings screen
```

---

## 8. Phase 1 — Day lifecycle

> **Scope:** Standalone only. No networking. Prerequisite for all Phase 2 and 3 stories.

---

### E11-P1-1 — Start day button `[x]`

**What to build:**

**Report screen — virtual today:**
- Remove `_EmptyState` entirely. `_ReportContent` is always shown.
- Add `isTodayVirtual` (bool) to `ReportState`.
- In `report_provider._load()`: if no `BusinessDay` exists for today, inject a virtual entry at index 0 (`day = null`, `isTodayVirtual = true`). Past days follow at index 1+.
- `_SummaryCard`: handle `day == null` — display today's date, "0 vente", "0,00 €". Remove the force-unwrap `report.day!`. No button or badge inside the card for the virtual case.
- `_ReportContent`: when `isTodayVirtual`, replace the `SegmentedButton` + content area with a new `_NotStartedState` widget (centred icon + `l10n.dayNotStarted` text + "Start day" button).
- Navigation: `canGoNext` = false when on virtual today (it is always the most recent entry).

**Start day action:**
- "Start day" button (in `_NotStartedState`) shows a confirmation dialog on tap.
- On confirm: `SalesRepository.getOrCreateToday()` creates the `BusinessDay`, provider refreshes.

**`SaleService` changes:**
- Replace `getOrCreateToday()` with `getToday()` — throw if no active day exists or if the day is closed.
- Remove the auto-reopen block (`if (businessDay.isClosed) reopenBusinessDay()` — lines 49-51).

**Cart screen:**
- Submit button disabled with tooltip `l10n.dayNotStarted` when no active day exists or day is closed.
- Cart remains fully composable (products, quantities, category filter all work).

**Acceptance criteria:**
- No sale can be recorded before "Start day" is pressed
- No sale can be recorded on a closed day
- Report always shows today (virtual or real) as the first entry — never a blank screen
- Segmented tabs and sale content are hidden when today is virtual; `_NotStartedState` is shown instead
- "Start day" button disappears after the day is started; normal report UI appears
- Navigating left from virtual today reaches the most recent past day (if any)
- Existing tests in `sale_service_test.dart` must be updated to reflect the new behaviour

---

### E11-P1-2 — Catalog lock `[x]`

**What to build:**
- When a `BusinessDay` is in progress (`opened_at` set, `closed_at` null):
  - Hide "Add product", "Edit product", "Delete product" buttons
  - Hide "Add category", "Rename category", "Delete category" buttons
  - Show a banner at the top of the Products screen: `l10n.catalogLocked`
- When the day is not started or closed: restore all editing buttons, remove banner

**Acceptance criteria:**
- No product or category can be created, modified, or deleted during an active day
- The locked state is derived from the `BusinessDay` in SQLite — survives app restart

---

### E11-P1-3 — Re-open current day `[x]`

**What to build:**
- "Re-open day" button on the report screen, visible only when:
  - A `BusinessDay` exists for today **and** it is closed (`closed_at` is set)
- On tap: confirmation dialog → `SalesRepository.reopenBusinessDay(id)` sets `closed_at` to null (method already exists)
- Only the current day (today) can be re-opened — past days are never re-openable

**Acceptance criteria:**
- After re-opening, sales are possible again and catalog editing is locked
- "Re-open" button is hidden when the day is in progress or not yet started

---

### E11-P1-4 — Auto-close past unclosed days `[x]`

**What to build:**
- On app launch: query `business_days` for rows where `date < today` and `closed_at IS NULL`
- For each found row: set `closed_at` to that date at `23:59:00`
- This check runs once, synchronously, before the UI renders (inside `DatabaseHelper` init or `AppNotifier`)

**Acceptance criteria:**
- A day left open from a previous session is automatically closed at 23:59 of its date on next launch
- No user interaction required

---

### E11-P1-5 — i18n (Phase 1) `[x]`

Add to `app_en.arb` and `app_fr.arb`. Run `flutter gen-l10n` after.

| Key | EN | FR |
|---|---|---|
| `startDay` | Start day | Démarrer la journée |
| `startDayConfirm` | Start the service? The catalog will be locked. | Démarrer le service ? Le catalogue sera verrouillé. |
| `reopenDay` | Re-open day | Ré-ouvrir la journée |
| `reopenDayConfirm` | Re-open the day? Sales will be possible again. | Ré-ouvrir la journée ? Les ventes seront à nouveau possibles. |
| `dayNotStarted` | Day not started | Journée non démarrée |
| `catalogLocked` | Service in progress — catalog locked | Service en cours — catalogue verrouillé |

---

### E11-P1-6 — Tests (Phase 1) `[x]`

| Test file | What to cover |
|---|---|
| `test/features/report/business_day_repository_test.dart` | `openDay`, `closeDay`, `reopenDay`, auto-close query |
| `test/features/report/business_day_notifier_test.dart` | State transitions: none → started → closed → reopened |
| `test/features/sales/sale_service_test.dart` | Sale blocked when no active day; sale allowed when day in progress |
| `test/features/products/catalog_lock_test.dart` | Lock state derived correctly from BusinessDay state |

---

## 9. Phase 2 — Basic connectivity

> **Scope:** HTTP server on control, HTTP client on second, manual sync buttons in settings.
> No real-time sync. Day lifecycle is independent on each device.

---

### E11-P2-1 — Role & sync settings section `[x]`

**What to build:**
- Add a role selector in the settings screen: `Standalone` / `Control` / `Second`
- Persisted in `SharedPreferences` (key: `AppConstants.keySyncRole`)
- A "Synchronization" section appears in settings for Control and Second roles
- **Control settings:**
  - Generated 6-digit PIN (persisted in `SharedPreferences`, key: `AppConstants.keySyncPin`)
  - "Regenerate" button (creates a new PIN, invalidates all existing tokens)
  - Live count: "X second(s) connected"
- **Second settings:**
  - IP field (pre-filled `192.168.43.1`, key: `AppConstants.keySyncControlIp`)
  - PIN input field
  - "Connect to control" button
  - Three action buttons (disabled when not connected):
    - "Download catalog" (available when day not in progress)
    - "Send sales" (available when day is closed)
    - "Download sales" (available when day is closed)
  - Connection status: "Connected to 192.168.43.1:8080" / "Not connected"
- In `Standalone` mode: sync section is hidden, behavior identical to current app

**Acceptance criteria:**
- Role is persisted and survives app restart
- PIN is generated once and persists; "Regenerate" creates a new one
- Action buttons are enabled/disabled according to day state and connection state

---

### E11-P2-2 — HTTP server (control) `[x]`

**What to build:**
- `SyncServer` class: starts a `shelf` HTTP server on port `8080` when app launches in Control mode
- Routes via `shelf_router`: all Phase 2 endpoints from §5
- In-memory connected seconds registry: `Map<String, ConnectedDevice>` keyed by token
- mDNS announcement via `MdnsService.announce()` on server start
- Android Foreground Service via `flutter_foreground_task` (`wakeLockEnabled: true`):
  - Notification title: `l10n.syncServiceNotificationTitle`
  - Notification body: `l10n.syncServiceNotificationBody(connectedCount)`
  - Started when server starts, stopped when server stops
- `AppLifecycleState.paused` is ignored in Control mode — server keeps running with screen off

**Acceptance criteria:**
- `GET /status` returns `200` with correct data
- Server remains reachable after the control's screen has been off for several minutes
- A persistent notification is visible in the Android status bar while the server is running
- All endpoints reject requests without a valid token with `401`

---

### E11-P2-3 — HTTP client + mDNS discovery (second) `[x]`

**What to build:**
- `SyncClient` class: thin wrapper around the `http` package
  - Injects `Authorization: Bearer <token>` header automatically
  - Retries once on network error, surfaces typed errors otherwise
  - Base URL from mDNS result or manual IP
- `MdnsService.discover()`: scans for `_festibuvette._tcp`, returns IP + port
- `SyncNotifier` connection flow: `disconnected` → `connecting` → `connected`
- On "Connect to control" tap: mDNS discovery → fallback to manual IP → `POST /auth`
- Token stored in `SharedPreferences` (key: `AppConstants.keySyncToken`)
- If stored token exists on app start: attempt reconnection automatically
- If auth fails (PIN changed): show "PIN required" prompt

**Acceptance criteria:**
- Second connects automatically on launch if a valid token is stored and control is reachable
- If mDNS fails, manual IP is used transparently
- If auth fails, the user is prompted to re-enter the PIN

---

### E11-P2-4 — Download catalog `[x]`

**What to build:**
- "Download catalog" button in sync settings section (second only)
- Calls `GET /sync/catalog`
- Replaces local `products` and `categories` in a single SQLite transaction
- Available only when the day is not in progress on the second's device
- Loading indicator during sync, error snackbar on failure

**Acceptance criteria:**
- After download, the second's product catalog matches the control's
- Operation is blocked (button disabled) when a day is in progress

---

### E11-P2-5 — Print delegation `[x]`

**What to build:**
- In Second mode, the "Print" button in the cart calls `SyncClient.print(items)` instead of `PrinterNotifier`
- The second sends name + price snapshots (already resolved locally) — no product lookup on control
- The second records the sale in its own local SQLite independently (not blocked by the print call)
- The second waits for the print response (spinner on button)
- On `200 OK`: show success snackbar, clear cart
- On `503 print_failed`: show existing "record without printing?" dialog
- On network error / timeout: show "Connection lost" error, cart preserved

**Control-side handler (`POST /print`):**
1. Build ESC/POS receipt from received items
2. Print via `PrinterNotifier`
3. Return `200 OK` or `503 print_failed`
4. Does **not** record any sale in SQLite

**Acceptance criteria:**
- Print request reaches the control and triggers Bluetooth printing
- The second's local sale is recorded regardless of print outcome (if operator confirms)
- Cart is never lost on network failure

---

### E11-P2-6 — Send sales (second → control) `[x]`

**What to build:**
- "Send sales" button in sync settings section (second only)
- Available only after the day is closed on the second's device
- Calls `POST /sales/push` with all of the second's sales for today
- Control merges received sales into its SQLite, skipping duplicates (by `local_id` + device token)
- Loading indicator, success snackbar ("X sales sent"), error snackbar on failure

**Acceptance criteria:**
- After sending, all of the second's sales are visible in the control's report
- Duplicate sends are idempotent (same sales are not counted twice)
- Button is disabled if day is not closed

---

### E11-P2-7 — Download sales (second ← control) `[x]`

**What to build:**
- "Download sales" button in sync settings section (second only)
- Available only after the day is closed on the second's device
- Calls `GET /sales/pull`
- Replaces the second's local sales for today in a single SQLite transaction
- Previous business days are left untouched

**Acceptance criteria:**
- After download, the second's report shows the same sales as the control (aggregated from all devices)
- Previous days are not affected

---

### E11-P2-8 — UI indicators (Phase 2) `[x]`

**What to build:**
- `ConnectionStatusIcon` widget added to the AppBar (hidden in Standalone mode):
  - Green WiFi icon: connected
  - Orange animated icon: connecting
  - Red icon with slash: disconnected
- Connection status text in the sync settings section

---

### E11-P2-9 — i18n (Phase 2) `[x]`

| Key | EN | FR |
|---|---|---|
| `syncRoleStandalone` | Standalone | Autonome |
| `syncRoleControl` | Control | Contrôle |
| `syncRoleSecond` | Second | Second |
| `syncSectionTitle` | Synchronization | Synchronisation |
| `syncConnected` | Connected | Connecté |
| `syncConnecting` | Connecting… | Connexion… |
| `syncDisconnected` | Not connected | Non connecté |
| `syncConnectButton` | Connect to control | Se connecter au contrôle |
| `syncPinLabel` | Connection PIN | Code PIN de connexion |
| `syncPinRegenerate` | Regenerate | Régénérer |
| `syncConnectedSeconds` | {count} second(s) connected | {count} second(s) connecté(s) |
| `syncConnectedTo` | Connected to: {address} | Connecté à : {address} |
| `syncDownloadCatalog` | Download catalog | Récupérer le catalogue |
| `syncSendSales` | Send sales | Envoyer les ventes |
| `syncDownloadSales` | Download sales | Récupérer les ventes |
| `syncSalesSent` | {count} sale(s) sent | {count} vente(s) envoyée(s) |
| `syncServiceNotificationTitle` | FestiBuvette — Service running | FestiBuvette — Service actif |
| `syncServiceNotificationBody` | {count} second(s) connected | {count} second(s) connecté(s) |
| `syncPrintFailed` | Printing failed. Record without printing? | Impression échouée. Enregistrer sans imprimer ? |
| `syncDayNotStartedOnControl` | Day not started on control | Journée non démarrée sur le contrôle |

---

### E11-P2-10 — Tests (Phase 2) `[x]`

| Test file | What to cover |
|---|---|
| `test/features/sync/sync_server_test.dart` | All HTTP endpoints: auth, catalog, print, sales push/pull |
| `test/features/sync/sync_client_test.dart` | Response parsing, error handling (401, 503, timeout) |
| `test/features/sync/sync_notifier_test.dart` | State transitions: disconnected → connecting → connected |

Use `shelf` test utilities and mock HTTP adapters — no physical network required.

---

## 10. Phase 3 — Real-time sync

> **Scope:** WebSocket-based push from control to seconds. Live sale broadcast, day start/close propagation.
> Builds on all Phase 2 infrastructure.

---

### E11-P3-1 — WebSocket server (control) `[ ]`

**What to build:**
- Add WebSocket route `WS /ws` to `SyncServer` via `shelf_web_socket`
- Each connected second upgrades its HTTP connection to WebSocket on connect
- `SyncServer` maintains a list of active WebSocket connections
- `SyncServer.broadcast(message)`: sends a JSON message to all connected seconds
- On WebSocket close: remove from active connections list

**Acceptance criteria:**
- Control can broadcast a message and all connected seconds receive it
- A disconnected second is removed from the broadcast list without error

---

### E11-P3-2 — WebSocket client (second) `[ ]`

**What to build:**
- `SyncClient` opens a `web_socket_channel` WebSocket to `ws://[control_ip]:8080/ws` after HTTP auth
- Listens for incoming JSON messages and dispatches to `SyncNotifier`
- Auto-reconnect with exponential backoff (2s → 4s → 8s → max 30s) on disconnect
- On reconnect: re-authenticate, re-open WebSocket

**Acceptance criteria:**
- Second receives broadcast messages from control in real time
- Reconnection is fully automatic after a network interruption

---

### E11-P3-3 — Day start/close broadcast `[ ]`

**What to build:**
- Control starts day → broadcasts `{ type: "day_started", payload: { business_day_id } }`
  - Each second receives the message → calls `BusinessDayRepository.openDay()` locally
- Control closes day → broadcasts `{ type: "day_closed", payload: { business_day_id } }`
  - Each second receives the message → calls `BusinessDayRepository.closeDay()` locally
- A second that connects after day start receives the current day state via `GET /status`

**Acceptance criteria:**
- Day start on control locks the catalog on all connected seconds within seconds
- Day close on control unlocks the catalog on all connected seconds within seconds
- A second that connects mid-day gets the correct state immediately

---

### E11-P3-4 — Sale notification `[ ]`

**What to build:**
- On any device (control or second): after recording a sale locally, send `POST /sales/notify` to control
- **Control-side handler:**
  1. Record the sale in its own SQLite (if not already from its own cart)
  2. Broadcast `{ type: "sale_added", payload: { sale, sale_lines } }` to all other connected seconds
- **Second receiving the broadcast:**
  - INSERT sale + sale lines into local SQLite
- The print request (`POST /print`) remains separate — sale recording and printing are independent

**Acceptance criteria:**
- A sale made on any device appears on all other devices' reports within a few seconds
- A sale made on the control while no seconds are connected is recorded locally without error

---

### E11-P3-5 — Disconnection handling (second side) `[ ]`

**What to build:**
- Disconnection detected via: WebSocket close, HTTP timeout, auth error
- `SyncState` transitions to `disconnected`
- Persistent red banner at top of screen: `l10n.syncDisconnectedBanner`
- Cart remains fully composable and sales are recorded locally
- Submit button still works (records locally + attempts print — print will fail if control unreachable)
- Background reconnection with exponential backoff
- On reconnect: re-sync missed sales via `GET /sales/pull`, remove banner

**Acceptance criteria:**
- A second that loses WiFi mid-cart does not lose the cart content
- Reconnection is fully automatic
- After reconnect, the second's report is consistent with the control's

---

### E11-P3-6 — Control failure fallback `[ ]`

**What to build:**
- After 5 consecutive failed reconnection attempts (~5 minutes with backoff), the disconnection banner gains an action button: **"Switch to standalone"**
- On tap: confirmation dialog → role switches to `Standalone` immediately
- In Standalone mode the second uses its local SQLite and `SaleService` directly
- Sales made in Standalone mode after the switch are not reconciled if control comes back (known limitation for a one-day festival)
- A tooltip on "Switch to standalone" documents this limitation

**Acceptance criteria:**
- After ~5 minutes of failed reconnection, the button appears
- Switching to Standalone allows the second to complete sales immediately
- A confirmation dialog warns the operator that sync is lost

---

### E11-P3-7 — i18n (Phase 3) `[ ]`

| Key | EN | FR |
|---|---|---|
| `syncDisconnectedBanner` | Connection lost — reconnecting… | Connexion perdue — reconnexion… |
| `syncSwitchToStandalone` | Switch to standalone | Passer en autonome |
| `syncSwitchToStandaloneConfirm` | Switch to standalone mode? Sales will no longer sync. This cannot be undone automatically. | Passer en mode autonome ? Les ventes ne seront plus synchronisées. Cette action ne peut pas être annulée automatiquement. |
| `syncControlUnreachable` | Control unreachable for too long | Contrôle inaccessible depuis trop longtemps |

---

### E11-P3-8 — Tests (Phase 3) `[ ]`

| Test file | What to cover |
|---|---|
| `test/features/sync/websocket_server_test.dart` | Broadcast to connected clients, disconnect handling |
| `test/features/sync/websocket_client_test.dart` | Message parsing, auto-reconnect backoff |
| `test/features/sync/sync_notifier_p3_test.dart` | day_started / day_closed / sale_added message handling |
| `test/features/sync/sale_notify_test.dart` | POST /sales/notify: control records + broadcasts |

---

## 11. Legend

| Symbol | Meaning |
|---|---|
| `[ ]` | To do |
| `[~]` | In progress |
| `[x]` | Done |
| `[!]` | Blocked |
