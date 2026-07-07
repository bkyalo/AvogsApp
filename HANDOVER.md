# AVO'Gs SalesApp — Handover Document

**Project:** `/Users/bentito/Documents/Spoiler/SalesApp`  
**Backend:** FrontAccounting retail API v2.3.1  
**API guide:** `/Users/bentito/Documents/Spoiler/FA/api/docs/MOBILE_APP_GUIDE.md`  
**Last updated:** 2026-07-07

---

## 1. What this app is

Cross-platform Flutter app (iOS, Android, Web/PWA) for AVO'Gs retail operations against the FA API:

- Direct sales (POS)
- Customer payments
- Supplier invoices (stock in)
- Stock adjustments

Target users: store staff on phone, tablet, or desktop browser.

---

## 2. What's done

### Foundation
| Area | Status |
|------|--------|
| Flutter project + Riverpod + go_router | Done |
| AVO'Gs theme (colors from `avogs_app.html`, DM Sans, light/dark) | Done |
| Auth: FA login → 4-digit PIN → biometric unlock | Done |
| 3 API environments (Local / Dev / Prod) in Settings | Done |
| Adaptive shell (Home / Services / Activity / Account) | Done |
| App icon + native splash + in-app avocado splash | Done |
| GitHub Actions CI (analyze + test + codegen) | Done |
| Drift DB for offline sync queue (native + web WASM) | Done |

### Core retail (Phase B)
| Screen | Status | Notes |
|--------|--------|-------|
| **POS / Direct sale** | Done | Prefill, catalog, cart, stock warnings, Cash/M-Pesa UI, receipt + PDF share/print |
| **Customer payment** | Done | Customer picker, amount, bank account, open invoice allocations |
| **Supplier invoice** | Done | Supplier picker, required `supplier_ref`, line entry |
| **Stock adjustment** | Done | Increase/decrease, memo, signed quantities |
| **Services hub** | Done | Grid launcher for all 4 transaction types |
| **Offline submit queue** | Done | Queues POST when offline; sync banner + manual sync |

### Tests
- **11 unit/widget tests** passing (PIN, config, transaction math, submit result, splash)
- Backend smoke test: **68/68** endpoints pass against local `:8090`

### Deployments verified
- **Web:** `flutter run -d chrome` / `flutter build web`
- **Android:** Debug APK built and installed on **SM S931B** (`R3CY80AZ42L`)

---

## 3. What's remaining

### Phase C — Dashboard & history (high priority)
| Item | Status | Work needed |
|------|--------|-------------|
| **Transaction history / Activity tab** | Placeholder only | List synced + API transactions; search/filter; tap → detail/receipt |
| **Dashboard sales summary** | Placeholder text | Wire `GET /reports/sales-trend?days=7` or equivalent; today's totals |
| **Store picker UI** | Partial | Settings has manual store code; should load `/stores` dropdown |
| **Customer picker on POS** | Partial | Defaults to CASH SALES (`customer_id: 1`); add picker + re-prefill |

### Phase D — Operations (from original full scope)
Not started. Routes exist in `app_routes.dart` but no screens:

| Feature | API prefix | Notes |
|---------|------------|-------|
| Shifts | `/shifts/*` | Open/close shift, current shift |
| Checklists | `/checklists/{mode}` | Morning/evening open flows |
| Ops logs | `/deliveries`, `/supplies`, `/expenses`, `/wastage` | Shadow tables, not FA GL |
| Photo uploads | `POST /uploads` | Multipart |
| Reports | `/reports/sales-trend` | Chart data |

### Offline / cache (partial)
| Item | Status |
|------|--------|
| Sync queue (writes) | Done |
| `CachedStores` Drift table | Schema only — **not wired** |
| Customers/suppliers/items cache for offline read | Not done — still API-only via `FutureProvider` |
| Catalog/prices offline read | Not done |
| Failed sync item UI (retry/discard) | Minimal — banner only |

### Quality & ship
| Item | Status |
|------|--------|
| Integration tests (login → sale E2E) | Not done |
| iOS build/signing test | Not done |
| Play Store / App Store release pipeline | Not done |
| Production web deploy + WASM headers | Not done |
| Barcode scanning | Deferred by product choice |

---

## 4. Known issues & dev gotchas

### Local API on physical Android
- FA API binds to **`localhost:8090` only** (not LAN).
- Phone cannot use `http://localhost:8090` without **USB port forwarding**:

```bash
adb reverse tcp:8090 tcp:8090
flutter run -d <device-id>
```

- Settings screen documents this under **Local** environment.
- Alternative: bind FA API to `0.0.0.0:8090` and use Mac LAN IP (e.g. `192.168.1.140`) — not implemented in app yet.

### API environments
| Environment | URL | Notes |
|-------------|-----|-------|
| Local | `http://localhost:8090/api` | Works on simulators + web; phone needs `adb reverse` |
| Dev | `https://avogsdev.werevu.co.ke/api` | Login returned **404** during testing — verify deployment |
| Prod | `https://avogs.werevu.co.ke/api` | Root responds; full flow not verified |

### Web (Drift)
Requires these files in `web/` (already present):
- `sqlite3.wasm` (sqlite3 2.9.4)
- `drift_worker.js` (drift 2.31.0)

Server must serve `.wasm` as `Content-Type: application/wasm`.

### Android
- `android:usesCleartextTraffic="true"` enabled for local HTTP.
- First Gradle build is slow (~5–10 min).

### Payment methods on POS
- Cash / M-Pesa is **UI-only** on receipt (not stored by API). Labels from `/payment-methods` not yet used.

---

## 5. How to run

### Prerequisites
- Flutter stable (3.44+ tested)
- Local FA API on port **8090** (see FA project)
- Test user: `apiuser` / `apiuser`

### Daily dev commands

```bash
cd ~/Documents/Spoiler/SalesApp

# Web
flutter run -d chrome

# Android (USB + port forward for local API)
adb reverse tcp:8090 tcp:8090
flutter run -d R3CY80AZ42L

# Tests
flutter test

# Codegen (after Drift schema changes)
dart run build_runner build --delete-conflicting-outputs
```

### First-time app flow
1. Open app → avocado splash
2. **Sign in** with FA credentials
3. **Create 4-digit PIN** (+ optional biometric)
4. **Settings → Environment → Local**
5. **Account → Store code** → e.g. `DEF`
6. **Services** → pick transaction type

---

## 6. Architecture (quick reference)

```
lib/
├── app.dart                    # MaterialApp, splash gate
├── core/
│   ├── api/                    # Dio client, error mapping
│   ├── auth/                   # Login, PIN, biometric
│   ├── config/                 # Environment + store
│   ├── database/               # Drift (sync queue)
│   ├── routing/                # go_router + auth guards
│   ├── sync/                   # Offline queue engine
│   ├── transactions/           # TransactionSubmitter
│   └── theme/                  # Colors, light/dark
├── features/
│   ├── auth/                   # Login, PIN screens
│   ├── dashboard/              # Home (partial)
│   ├── services/               # Transaction launcher
│   ├── sales/                  # POS + receipt
│   ├── payments/
│   ├── purchasing/
│   ├── inventory/
│   ├── history/                # PLACEHOLDER
│   ├── settings/
│   └── master_data/            # Stores, customers, suppliers
└── shared/
    ├── models/
    ├── widgets/
    └── services/               # Receipt PDF
```

**Transaction flow:** `GET …/prefill` → user edits → `TransactionSubmitter.submit()` → online POST or offline queue → success/receipt screen.

---

## 7. Recommended next steps (priority order)

1. **Activity / history screen** — highest user-visible gap
2. **Dashboard sales summary** — `GET /reports/sales-trend`
3. **Store dropdown** from `/stores` (replace manual code entry)
4. **Customer picker on POS** with re-prefill
5. **Wire `CachedStores` + master data cache** for true offline read
6. **Failed sync queue UI** — list, retry, discard
7. **Phase D ops** — shifts, checklists, ops logs (if still in scope)
8. **Integration tests** + fix dev API deployment
9. **Production release** — signing, store listings, web hosting

---

## 8. Key files to read first

| File | Why |
|------|-----|
| `MOBILE_APP_GUIDE.md` (FA repo) | API contract |
| `lib/core/routing/app_router.dart` | Navigation map |
| `lib/core/transactions/transaction_submitter.dart` | Online/offline submit |
| `lib/features/sales/application/pos_controller.dart` | POS logic template |
| `lib/core/config/app_environment.dart` | API URLs |
| `lib/core/database/connection/web.dart` | Web Drift setup |

---

## 9. Contacts & credentials

- **Local API:** `http://localhost:8090/api`
- **Swagger:** `http://localhost:8090/api/docs/`
- **Dev API:** `https://avogsdev.werevu.co.ke/api`
- **Prod API:** `https://avogs.werevu.co.ke/api`
- **Test login:** `apiuser` / `apiuser`

---

*End of handover.*
