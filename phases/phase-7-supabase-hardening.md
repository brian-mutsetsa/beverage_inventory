# Phase 7: Supabase Hardening & Sync Polish

**Status**: NOT STARTED
**Depends on**: Phase 1 (Bug Fixes), Phase 4 (Order Tracking — need to sync orders tables too)
**Complexity**: Medium-High
**New files**: 1-2 (`.env`, `.env.example`) | **Modified files**: 3-5 | **New packages**: 1 (`flutter_dotenv`)

---

## Goal
Harden the Supabase integration with basic Row-Level Security, incremental sync, environment-based config, retry logic, and sync support for the new orders tables from Phase 4.

---

## Steps

### Step 7.1 — Basic Row-Level Security (RLS)
Prevent one company's data from being accessed by another at the database level.

**Actions:**

1. **Enable RLS on all Supabase tables**:
   - Tables: `products`, `sales`, `users`, `audit_logs`, `orders`, `order_items`
   - In Supabase Dashboard → Table Editor → each table → Enable RLS
   - [ ] RLS enabled on `products`
   - [ ] RLS enabled on `sales`
   - [ ] RLS enabled on `users`
   - [ ] RLS enabled on `audit_logs`
   - [ ] RLS enabled on `orders`
   - [ ] RLS enabled on `order_items`

2. **Create company_id-scoped policies**:
   - Since the app doesn't use Supabase Auth (we do PIN-based local auth), RLS policies will use the `company_id` column
   - Approach: use a service role key for writes (server-side trust) and add filter on reads
   - Policy per table:
     ```sql
     CREATE POLICY "company_isolation_select" ON products
       FOR SELECT USING (company_id = current_setting('app.company_id', true));
     ```
   - Alternative (simpler): since this is single-company and we control the app, enable RLS but use service role key which bypasses RLS for now. Add proper RLS when multi-company is needed.
   - **Decision**: Use **service role key approach** for now (single-company). Document proper RLS policies for future multi-company expansion.
   - [ ] RLS enabled (prevents anonymous access)
   - [ ] Service role key used for app access
   - [ ] Proper multi-company RLS policies documented for future

3. **Verify anonymous access is blocked**:
   - Test: try to read a table with the `anon` key → should get empty result or error
   - [ ] Anonymous access blocked on all tables

---

### Step 7.2 — Incremental Sync
Currently the app does a full-table sync. Switch to only syncing records changed since the last sync.

**Actions:**

1. **Add `last_synced_at` tracking**:
   - Store per-table sync timestamps in SharedPreferences or a new SQLite `sync_meta` table
   - Keys: `sync_products_last`, `sync_sales_last`, `sync_orders_last`, etc.
   - [ ] Sync timestamp storage implemented

2. **Modify push sync** in `sync_service.dart`:
   - Currently: push all records on every sync
   - Change to: query local records where `updatedAt > lastSyncedAt` for that table
   - After successful push, update `lastSyncedAt` to now
   - Keep full-sync as a fallback option (e.g., manual "Force Full Sync" button)
   - [ ] Push sync only sends changed records
   - [ ] `lastSyncedAt` updated after successful push

3. **Modify pull sync** in `sync_service.dart`:
   - Query Supabase with filter: `.gte('updated_at', lastSyncedAt)`
   - Upsert pulled records into local SQLite
   - Update `lastSyncedAt` after successful pull
   - [ ] Pull sync only fetches changed records
   - [ ] Local database updated correctly with pulled changes

4. **First-run handling**:
   - If no `lastSyncedAt` exists → do a full sync (first time)
   - After first full sync, switch to incremental
   - [ ] First-run triggers full sync
   - [ ] Subsequent syncs are incremental

---

### Step 7.3 — Environment Variables
Move Supabase credentials out of source code.

**Actions:**

1. **Add `flutter_dotenv` package**:
   - Add to `pubspec.yaml` and run `flutter pub get`
   - [ ] Package added

2. **Create `.env` file** (project root):
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key
   SUPABASE_SERVICE_ROLE_KEY=your-service-key
   ```
   - [ ] `.env` file created with real values

3. **Create `.env.example` file** (project root):
   ```
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here
   ```
   - [ ] `.env.example` created with placeholder values

4. **Add `.env` to `.gitignore`**:
   - Ensure real credentials are never committed
   - [ ] `.env` added to `.gitignore`

5. **Update `supabase_config.dart`**:
   - Replace hardcoded strings with `dotenv.env['SUPABASE_URL']` etc.
   - Load dotenv in `main.dart` before `runApp()`: `await dotenv.load()`
   - Add `.env` to `pubspec.yaml` assets
   - [ ] `supabase_config.dart` reads from env vars
   - [ ] `main.dart` loads dotenv on startup
   - [ ] `.env` listed in pubspec assets

6. **Verify**:
   - App starts and connects to Supabase using env vars
   - Remove or comment out old hardcoded credentials
   - [ ] App connects via env vars
   - [ ] No hardcoded credentials remain in source

---

### Step 7.4 — Retry Logic with Exponential Backoff
Make sync resilient to network failures.

**Actions:**

1. **Create retry helper** (in `sync_service.dart` or a small helper):
   - Retry wrapper function:
     ```dart
     Future<T> withRetry<T>(Future<T> Function() fn, {int maxRetries = 3}) async {
       for (int attempt = 0; attempt <= maxRetries; attempt++) {
         try {
           return await fn();
         } catch (e) {
           if (attempt == maxRetries) rethrow;
           await Future.delayed(Duration(seconds: pow(2, attempt).toInt()));
         }
       }
       throw Exception('Retry failed');
     }
     ```
   - [ ] Retry helper implemented

2. **Wrap all Supabase calls** in sync_service with retry:
   - Push operations: retry up to 3 times
   - Pull operations: retry up to 3 times
   - Real-time listener: auto-reconnect is handled by Supabase SDK, but add a manual reconnect trigger
   - [ ] Push sync wrapped with retry
   - [ ] Pull sync wrapped with retry

3. **Offline queue** (optional, improves reliability):
   - If a push fails after all retries, mark the record in a `pending_sync` flag in SQLite
   - On next sync attempt, retry pending records first
   - [ ] Pending sync tracking implemented (or deferred)

4. **User feedback**:
   - Show a snackbar or indicator when sync fails and is retrying
   - Show "Offline — changes will sync when connection returns" message
   - [ ] Retry feedback visible to user
   - [ ] Offline state communicated clearly

---

### Step 7.5 — Sync Orders Tables
Extend sync to cover the `orders` and `order_items` tables added in Phase 4.

**Actions:**

1. **Create Supabase tables** (if not done in Phase 4):
   - `orders`: id, company_id, customer_name, customer_phone, status, total_amount, notes, created_at, updated_at
   - `order_items`: id, order_id, product_id, product_name, quantity, unit_price, subtotal
   - [ ] `orders` table exists in Supabase
   - [ ] `order_items` table exists in Supabase

2. **Add orders sync to `sync_service.dart`**:
   - `pushOrders()`: push local orders + order_items to Supabase
   - `pullOrders()`: pull remote orders + order_items to local
   - Handle the parent-child relationship: push orders first, then order_items
   - [ ] `pushOrders()` implemented
   - [ ] `pullOrders()` implemented
   - [ ] Parent-child relationship handled correctly

3. **Add to full sync cycle**:
   - Include orders and order_items in the existing `syncAll()` method
   - Apply incremental sync (Step 7.2) to orders tables too
   - [ ] Orders included in `syncAll()`
   - [ ] Incremental sync works for orders

4. **Real-time listener for orders** (optional):
   - Subscribe to orders table changes in Supabase real-time
   - Update local database when remote order status changes
   - [ ] Real-time orders listener added (or deferred)

---

### Step 7.6 — Testing

**RLS:**
- [ ] With service role key → all CRUD operations work
- [ ] With anon key → reads return empty / writes rejected
- [ ] App functions normally with RLS enabled

**Incremental Sync:**
- [ ] Modify one product locally → sync → only that product pushed (check Supabase logs or network)
- [ ] Modify one product in Supabase → sync → only that product pulled
- [ ] First install (no sync history) → full sync executes
- [ ] Second sync → incremental (much faster)
- [ ] Force Full Sync button → full sync still works

**Environment Variables:**
- [ ] App starts with `.env` file present → connects to Supabase
- [ ] Remove `.env` → app handles missing vars gracefully (error message, not crash)
- [ ] `.env` is NOT in git history (`git status` / `.gitignore` check)
- [ ] `.env.example` IS committed and has placeholder values

**Retry Logic:**
- [ ] Turn off wifi → attempt sync → retry messages appear
- [ ] Turn wifi back on → next retry succeeds
- [ ] After max retries → clear error message shown
- [ ] Pending records sync on next successful attempt (if offline queue implemented)

**Orders Sync:**
- [ ] Create order locally → sync → order appears in Supabase
- [ ] Update order status locally → sync → status updated in Supabase
- [ ] Order items sync correctly alongside parent order
- [ ] Pull orders from Supabase → appear in local app

---

## Definition of Done
Supabase access is secured with RLS, sync is incremental and resilient, credentials are not in source code, and orders tables sync alongside existing tables.

---

## Issues Found During This Phase

| # | Issue | File(s) | Status |
|---|-------|---------|--------|
| | | | |

---

## Phase Sign-Off
- [ ] All steps completed
- [ ] All tests passed
- [ ] No blocking issues remaining
- [ ] All 7 phases complete — app is production-ready for single-company use
