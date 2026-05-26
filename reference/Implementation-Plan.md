# Aura — Implementation Plan

## How We'll Complete the App (Phase by Phase)

Based on the [April 2026 Audit](Audit-April-2026.md), here's every remaining piece of work broken into **7 phases**. Each phase is self-contained — we'll implement it, test it, and confirm it works before moving on.

---

## Phase Overview

| Phase | Name | What It Covers | Depends On |
|-------|------|---------------|------------|
| 1 | Bug Fixes & Verification | Verify/fix escaped `$` bugs, clean up deprecated code | Nothing |
| 2 | Security Hardening | PIN hashing, session timeout, PIN validation, secure storage | Phase 1 |
| 3 | Sales & Checkout Upgrade | Multi-item cart, stock adjustment screen, receipt view | Phase 1 |
| 4 | Customer Order Tracking | Order model, order workflow, order screens, order history | Phase 3 |
| 5 | UX Enhancements | Barcode scanning, camera capture, dark mode, dashboard charts | Phase 1 |
| 6 | Advanced AI | Seasonal trends, anomaly detection, price optimization | Phase 1 |
| 7 | Supabase Production Hardening | Proper RLS, incremental sync, env variables, retry logic | Phase 2 |

> **Single-Company Focus**: Since there is no admin panel or multi-company management layer, we are building for **one company per device** for now. The `companyId` field stays in the database and queries (it's already built and costs nothing to keep), but we won't spend any time on multi-company edge cases, cross-company testing, or company-switching flows. This keeps things simple and focused. Multi-company support can be revisited if/when an admin app is built.

---

## Phase 1: Bug Fixes & Verification

**Goal**: Make sure the existing app is 100% stable before adding anything new.

**Why first**: Any bugs in the foundation will cascade into new features. We clean the house before building extensions.

### Step 1.1 — Verify String Interpolation Bugs
The Progress Report flagged several escaped `$` bugs that were marked "FIXING NOW." We need to verify each one is actually fixed.

**Files to check:**
- `lib/screens/manager_auth_screen.dart` — companyId generation (`company_\${DateTime...}` → should be `company_${DateTime...}`)
- `lib/screens/manager_auth_screen.dart` — success dialog (`Your company "\$companyName"` → should be `Your company "$companyName"`)
- `lib/services/ai_service.dart` — error message (`Error training model: \$e` → should be `Error training model: $e`)
- `lib/screens/ai_detailed_forecast_screen.dart` — forecast values (`\${product.quantity}` → should be `${product.quantity}`)

**What we'll do:**
1. Open each file and search for `\$` (backslash-dollar)
2. Fix any escaped interpolation that should be live interpolation
3. Search the entire codebase for any other `\$` occurrences that look wrong

### Step 1.2 — Remove or Integrate Deprecated Setup Screen
`lib/screens/setup_screen.dart` appears to be an older alternative to `manager_auth_screen.dart`. It's not referenced in any navigation flow.

**What we'll do:**
1. Confirm `setup_screen.dart` is not referenced anywhere
2. If unused, remove it to reduce confusion
3. If partially used, consolidate into the manager auth flow

### Step 1.3 — Verify All Database Queries Filter by companyId
The Progress Report said this was fixed. We'll do a quick sanity check (single-company focus, so this is low-risk).

**What we'll do:**
1. Quick scan of `database_helper.dart` to confirm all queries include `companyId`
2. Confirm `readProduct(id)`, `deleteProduct(id)`, and `deleteSale(id)` work correctly for the single registered company

### Step 1.4 — Test the Full Flow
**Manual testing checklist:**
- [ ] Fresh install → Tutorial → Register company → Login with generated PIN
- [ ] Load demo data → Verify 10 products, 5 staff, 30+ days of sales appear
- [ ] Record a sale → Check stock decremented → Check sale in history
- [ ] Add/edit/delete a product (as manager)
- [ ] Login as staff → Confirm restricted access (no delete, no profit reports, no AI insights)
- [ ] Check AI forecast screen → Confirm numbers display (not literal `${variable}`)
- [ ] Export a PDF report → Confirm it downloads/prints
- [ ] Clear all data → Verify everything resets except manager account

> **Note:** No multi-company or company-switching testing needed. We're focused on one company per device.

**Done when**: All bugs verified fixed, deprecated code removed, full flow tested clean.

---

## Phase 2: Security Hardening

**Goal**: Bring authentication and data security up to a production-acceptable standard.

**Why second**: Security bugs are invisible but dangerous. Fixing them early means every feature built afterward inherits proper security.

### Step 2.1 — Hash PINs Before Storage
PINs are currently stored as plaintext in SQLite and synced as plaintext to Supabase.

**What we'll do:**
1. Add `crypto` package to `pubspec.yaml`
2. Create a `security_helper.dart` utility with:
   - `hashPin(String pin)` → returns SHA-256 hash
   - `verifyPin(String input, String storedHash)` → returns bool
3. Update `database_helper.dart`:
   - `createUser()` — hash the PIN before inserting
   - `getUserByPin()` — hash the input PIN, then query by hash
   - `generateUniquePIN()` — hash before uniqueness check
4. Update `manager_auth_screen.dart` — hash PIN on registration
5. Update `user_management_screen.dart` — hash PIN on staff creation and PIN reset
6. Write a one-time migration: hash all existing plaintext PINs in the database
7. Update Supabase sync to push hashed PINs (never plaintext)

**Important**: The PIN display in the success dialog still shows the original plaintext PIN to the user (so they can write it down). We only hash what's stored.

### Step 2.2 — PIN Complexity Validation
Prevent weak PINs like `111111`, `123456`, `AAAAAA`.

**What we'll do:**
1. Add validation in `security_helper.dart`:
   - Reject PINs where all characters are the same
   - Reject common sequences (`123456`, `ABCDEF`)
   - Require at least 1 letter and 1 digit (already enforced by generation, but validate on input too)
2. Apply validation in `generateUniquePIN()` — regenerate if weak
3. Apply validation in `setup_screen.dart` (if kept) for manual PIN entry

### Step 2.3 — Session Timeout
Auto-logout after period of inactivity.

**What we'll do:**
1. Create a `session_manager.dart` service:
   - Tracks last interaction timestamp
   - Configurable timeout (default: 15 minutes)
   - `resetTimer()` called on any user interaction
   - `isExpired()` check
2. Wrap the `HomeScreen` (main navigation container) with an activity listener
3. On timeout: show "Session expired" dialog → navigate to login screen
4. Store timeout preference in SharedPreferences (manager can configure)

### Step 2.4 — Secure Storage for Sensitive Data
Move sensitive values out of plain SharedPreferences.

**What we'll do:**
1. Add `flutter_secure_storage` package
2. Move these values from SharedPreferences to secure storage:
   - `companyId`
   - Any cached user credentials
3. Update `splash_screen.dart`, `login_screen.dart`, and `manager_auth_screen.dart` to read from secure storage

### Step 2.5 — Testing
- [ ] Register new company → Verify PIN is hashed in database (inspect SQLite)
- [ ] Login with correct PIN → Works
- [ ] Login with wrong PIN → Rejected
- [ ] Create staff member → PIN shown in dialog, but hashed in DB
- [ ] Reset PIN → Old PIN stops working, new PIN works, new hash in DB
- [ ] Wait 15 minutes idle → Session expires, redirected to login
- [ ] Verify companyId stored in secure storage (not plain SharedPreferences)
- [ ] Load demo data → Verify demo users have hashed PINs

**Done when**: No plaintext PINs in storage, session timeout works, secure storage in use.

---

## Phase 3: Sales & Checkout Upgrade

**Goal**: Transform the single-item POS into a proper multi-item checkout with stock management tools.

**Why third**: This is a high-impact UX improvement that directly affects daily usage. Better checkout = happier staff and more accurate records.

### Step 3.1 — Multi-Item Cart (Batch Sales)
Currently sales are recorded one product at a time. We'll add a shopping cart.

**What we'll do:**
1. Create a `CartItem` model: `{product, quantity, unitPrice, lineTotal}`
2. Create a `cart_service.dart` (or in-screen state):
   - `addItem(product, quantity)`
   - `removeItem(productId)`
   - `updateQuantity(productId, newQty)`
   - `clearCart()`
   - `getTotal()` → sum of all line totals
   - `getItemCount()`
3. Redesign `sales_screen.dart`:
   - Top section: product selector + quantity + "Add to Cart" button
   - Middle section: scrollable cart list showing each item (product, qty, line total, remove button)
   - Bottom section: cart total + "Charge All" button
   - "Charge All" creates one `Sale` record per cart item, decrements each product's stock, logs each to audit trail
4. Update the sale recording logic to handle batch operations in a database transaction (all-or-nothing)
5. Keep "Recent Sales" section below the cart

### Step 3.2 — Stock Adjustment Screen
Managers need a way to add stock (received deliveries) and correct counts (physical inventory check) without going through the product edit form.

**What we'll do:**
1. Create `lib/screens/stock_adjustment_screen.dart`:
   - Product selector dropdown
   - Adjustment type: "Received Delivery" (+) or "Inventory Correction" (±)
   - Quantity field (positive for additions, can be negative for corrections)
   - Reason/notes field (required)
   - "Apply" button → updates product quantity, logs audit trail with details
2. Add "Adjust Stock" quick action on dashboard (manager only)
3. Add adjustment history view (filtered audit logs where action = 'stock_adjustment')
4. Update `database_helper.dart` with `adjustStock(productId, quantityDelta, reason)` method

### Step 3.3 — Sale Receipt View
After a successful checkout, show a receipt-style summary.

**What we'll do:**
1. Create a receipt dialog/screen that shows after "Charge":
   - Company name at top
   - Each item: product name, quantity, unit price, line total
   - Subtotal
   - Date/time
   - Served by: employee name
   - Optional: "Print Receipt" button (using `printing` package, already in deps)
2. This is a read-only view, no new data models needed

### Step 3.4 — Testing
- [ ] Add 3 different products to cart → Verify totals update correctly
- [ ] Remove an item from cart → Verify total recalculates
- [ ] Charge all → All products' stock decremented, all sales recorded, audit logged
- [ ] Try to add more than available stock → Error message
- [ ] Stock adjustment: receive 50 units → Product quantity increases by 50
- [ ] Stock adjustment: correction -5 → Product quantity decreases by 5
- [ ] Receipt shows after checkout with all items listed
- [ ] Print receipt → PDF renders correctly

**Done when**: Multi-item checkout works, stock adjustments work, receipts display and print.

---

## Phase 4: Customer Order Tracking (Internal — Option A)

**Goal**: Add an internal order management workflow where **employees** create and track orders on behalf of customers (walk-ins, phone calls, etc.). No customer-facing login or app access.

**Why fourth**: This was listed as a project objective ("monitor customer orders") and was called out as 0% complete. Builds naturally on the upgraded sales system from Phase 3.

> **Scope clarification**: This is "Option A" — internal order management. Employees record orders; customers never interact with the app directly. See "Future Consideration: Customer-Facing Ordering (Option B)" at the bottom of this document for the alternative approach.

### Step 4.1 — Data Model
Create the order infrastructure.

**What we'll do:**
1. Create `lib/models/order.dart`:
   ```
   Order {
     id, companyId, customerName, customerPhone, customerAddress?,
     status (pending/processing/completed/delivered/cancelled),
     items (list of OrderItem),
     totalAmount, notes?,
     createdAt, updatedAt, createdBy (userId)
   }
   ```
2. Create `lib/models/order_item.dart`:
   ```
   OrderItem {
     id, orderId, productId, productName, quantity, unitPrice, lineTotal
   }
   ```
3. Add two new tables to `database_helper.dart`:
   - `orders` table with companyId filter
   - `order_items` table linked to orders
4. Bump database version to 4 with migration
5. Add companyId indexes on new tables
6. Add CRUD methods: `createOrder()`, `getOrders()`, `getOrderById()`, `updateOrderStatus()`, `getOrdersByCustomer()`

### Step 4.2 — Order Creation Screen
Allow creating orders from the cart (alternative to immediate "Charge").

**What we'll do:**
1. Create `lib/screens/create_order_screen.dart`:
   - Customer info section: name (required), phone, address (optional)
   - Items section: reuse cart component from Phase 3
   - Notes field
   - "Place Order" button → creates order with status "pending", does NOT decrement stock yet
2. Add "Place Order" option alongside "Charge" on the sales screen
3. Order placement triggers audit log entry

### Step 4.3 — Order Management Screen
View and manage all orders.

**What we'll do:**
1. Create `lib/screens/orders_screen.dart`:
   - Filter tabs: All / Pending / Processing / Completed / Delivered
   - Order cards showing: customer name, item count, total, status badge (color-coded), date
   - Tap card → order detail view
2. Create `lib/screens/order_detail_screen.dart`:
   - Full order info: customer details, item list, total, timestamps
   - Status progression buttons:
     - Pending → "Start Processing" (decrements stock at this point)
     - Processing → "Mark Completed"
     - Completed → "Mark Delivered"
     - Any status → "Cancel Order" (returns stock if already decremented)
   - Status change history/timeline
3. Add "Orders" as a 5th tab in the bottom navigation (or as an entry from dashboard)

### Step 4.4 — Customer History
Allow looking up a customer's past orders.

**What we'll do:**
1. Add `getOrdersByCustomer(phone)` to database helper
2. Add a "Customer Lookup" search on the orders screen
3. Show list of past orders for that customer with totals

### Step 4.5 — Supabase Sync for Orders
Extend cloud sync to cover the new tables.

**What we'll do:**
1. Add `orders` and `order_items` tables to Supabase schema
2. Update `supabase_service.dart` with order CRUD methods
3. Update `sync_service.dart` with push/pull for orders
4. Add real-time listeners for order table changes

> Single-company only — no cross-company order isolation testing needed.

### Step 4.6 — Testing
- [ ] Create order with customer info + 3 items → Saved as "pending", stock NOT changed
- [ ] Move order to "processing" → Stock decremented for all items
- [ ] Move to "completed" → Status updates, stock unchanged
- [ ] Move to "delivered" → Final status
- [ ] Cancel a "processing" order → Stock restored
- [ ] Cancel a "pending" order → No stock change needed
- [ ] Search by customer phone → Show order history
- [ ] Verify orders sync to Supabase
- [ ] Real-time: update order status on Device A → Reflected on Device B

**Done when**: Full order lifecycle works, customer history works, syncs to cloud.

---

## Phase 5: UX Enhancements

**Goal**: Add quality-of-life features that make the app feel polished and professional.

**Why fifth**: These are nice-to-haves that improve the experience but aren't blockers. All core business logic should be done first.

### Step 5.1 — Dashboard Charts
Add visual analytics to the dashboard (currently only in Reports tab).

**What we'll do:**
1. Add `fl_chart` package (lightweight Flutter charts)
2. Add to dashboard screen:
   - Mini sales trend line chart (last 7 days)
   - Category breakdown donut/pie chart
3. Make charts tappable → navigate to full Reports tab
4. Only show charts for manager role

### Step 5.2 — Dark Mode
**What we'll do:**
1. Define a dark theme in `main.dart` alongside current light theme
2. Add theme toggle in dashboard menu (or settings)
3. Persist theme choice in SharedPreferences
4. Use `ThemeMode.system` as default (follow device setting)
5. Audit all screens for hardcoded colors that don't respect theme

### Step 5.3 — Animated Screen Transitions
**What we'll do:**
1. Add custom `PageRouteBuilder` transitions for navigation
2. Fade transitions for tab switches
3. Slide-up for modals/dialogs
4. Hero animations for product cards → product detail

### Step 5.4 — Testing
- [ ] Dashboard charts show accurate 7-day trend and category breakdown
- [ ] Toggle dark mode → All screens render correctly
- [ ] Switch back to light mode → Persists across app restart
- [ ] Screen transitions are smooth and consistent

**Done when**: Charts, dark mode, and animations all working.

---

## Phase 6: Advanced AI

**Goal**: Expand the AI capabilities beyond basic linear regression into more sophisticated business intelligence.

**Why sixth**: The current AI features are already functional and meet academic requirements. These are enhancements that add real commercial value.

### Step 6.1 — Seasonal Trend Detection
**What we'll do:**
1. Extend `ai_service.dart` with `getSeasonalTrends()`:
   - Analyze month-over-month patterns (requires 60+ days of data)
   - Detect recurring monthly spikes (e.g., end-of-month payday surge)
   - Detect weekly cycle patterns beyond just best/worst day
2. Add seasonal insights to the AI Insights widget
3. Show "Seasonal Alert" cards when an upcoming spike is predicted
4. Fallback message when insufficient data for seasonal analysis

### Step 6.2 — Anomaly Detection
**What we'll do:**
1. Add `getAnomalies()` to `ai_service.dart`:
   - Calculate rolling mean and standard deviation for each product
   - Flag any day where sales deviate >2 standard deviations from the mean
   - Classify as "Unusual Spike" or "Unusual Drop"
2. Add anomaly alerts to dashboard (e.g., "Coca-Cola sales were 3x normal yesterday — investigate?")
3. Log anomalies for historical review

### Step 6.3 — Price Optimization Suggestions
**What we'll do:**
1. Add `getPriceSuggestions()` to `ai_service.dart`:
   - For high-demand, low-margin products: suggest price increase
   - For low-demand, high-margin products: suggest promotional pricing
   - Calculate elasticity estimate based on price vs volume history
2. Show suggestions in a new "Pricing Insights" section on the AI detailed forecast screen
3. Manager can dismiss or act on suggestions

### Step 6.4 — Supplier Performance Tracking
**What we'll do:**
1. Create `lib/models/supplier.dart`: `{name, phone, email, products[], leadTimeDays, rating}`
2. Add suppliers table to database
3. Create `lib/screens/suppliers_screen.dart`:
   - List of suppliers with product count and average lead time
   - Add/edit supplier details
   - Link products to suppliers (products already have a `supplier` text field — upgrade to foreign key)
4. Track reorder history: when manager restocks, record supplier + delivery time
5. Calculate supplier reliability score (on-time delivery %)
6. AI service method: `getSupplierInsights()` ranking suppliers by reliability

### Step 6.5 — Testing
- [ ] With 60+ days of data: seasonal trends detected and displayed
- [ ] Anomaly detection flags unusual sales spikes/drops
- [ ] Price suggestions appear for appropriate products
- [ ] Supplier added → linked to products → delivery tracked
- [ ] Supplier reliability score calculates correctly
- [ ] Insufficient data → graceful fallback messages (not crashes)

**Done when**: All 4 advanced AI features functional with proper fallbacks.

---

## Phase 7: Supabase Production Hardening

**Goal**: Make the cloud sync layer production-ready and secure.

**Why last**: The app works fully offline. Cloud hardening is about preparing for real multi-device deployment with proper security — it requires all features to be built first so we can secure everything at once.

### Step 7.1 — Basic Row-Level Security (RLS)
Currently RLS policies are "allow all." Since we're single-company for now, the risk is lower, but we should still tighten things up.

**What we'll do:**
1. Replace the wide-open RLS policies with company_id-scoped policies using a service role or request header
2. Ensure the Flutter app passes company_id context when syncing
3. Update all tables with basic company-scoped RLS
4. Full Supabase Auth (JWT, email/password) can wait until multi-company support is needed

### Step 7.2 — Incremental Sync
Currently `fullSync()` pulls ALL records for a company. This doesn't scale.

**What we'll do:**
1. Add `last_synced_at` timestamp to local database
2. On sync: only pull records where `synced_at > last_synced_at`
3. Update `sync_service.dart` `fullSync()` to accept and use timestamp
4. Track per-table sync timestamps
5. Fall back to full sync if `last_synced_at` is null (first sync)

### Step 7.3 — Environment Variables for Credentials
Supabase URL and anon key are hardcoded in `supabase_config.dart`.

**What we'll do:**
1. Add `flutter_dotenv` package
2. Create `.env` file (gitignored) with SUPABASE_URL and SUPABASE_ANON_KEY
3. Update `supabase_config.dart` to read from environment
4. Add `.env.example` with placeholder values for other developers
5. Update README with setup instructions

### Step 7.4 — Retry Logic with Exponential Backoff
Cloud operations currently fire-and-forget with no retry.

**What we'll do:**
1. Create `retry_helper.dart`:
   - Accepts an async function
   - Retries on failure: 1s → 2s → 4s → 8s → give up
   - Max 4 retries
   - Only retries on network errors (not validation errors)
2. Wrap all push operations in `sync_service.dart` with retry logic
3. Add an offline queue: failed pushes saved to a `pending_sync` table
4. On connectivity restored: process pending queue

### Step 7.5 — Sync Orders Tables
Ensure the new orders and order_items tables from Phase 4 are fully synced.

**What we'll do:**
1. Add Supabase schema for `orders` and `order_items`
2. Add RLS policies scoped by company_id
3. Real-time listeners for order status changes
4. Push order creation and status updates in sync service

### Step 7.6 — Testing
- [ ] With RLS: Supabase rejects requests without valid company_id context
- [ ] Incremental sync: only new/updated records transferred
- [ ] `.env` credentials load correctly, app starts normally
- [ ] Kill network mid-sync → Operation queued → Reconnect → Queue processed
- [ ] Orders sync correctly across devices
- [ ] Full offline workflow → Reconnect → All pending changes pushed

**Done when**: Cloud layer is production-secure with proper auth, RLS, incremental sync, and retry logic.

---

## Future Consideration: Multi-Company & Admin App

Not part of this plan. Listed here so we don't lose track of the idea.

### What Would Be Needed
- An admin panel (web dashboard or dedicated app) to manage multiple companies
- Proper Supabase Auth with JWT tokens tied to company_id
- Company registration approval/deactivation workflow
- Cross-company analytics

### When to Revisit
After the single-company app is fully complete and deployed. The `companyId` field is already in every table and query, so the data model is ready — it's the management layer that's missing.

### What We've Preserved
By keeping `companyId` in the schema, we haven't painted ourselves into a corner. A second company could be added by simply registering a new companyId. The migration to multi-company would be about building the admin layer, not reworking the database.

---

## Future Consideration: Customer-Facing Ordering (Option B)

Not part of this plan. This is a significant scope expansion that would essentially be a second product.

### What It Would Be
A customer-facing ordering system where customers can browse a company's products and place orders themselves, without an employee acting as intermediary.

### What It Would Require
- **Customer authentication**: Email/phone login (completely separate from the PIN system used by staff)
- **Company discovery**: How a customer finds the right company — options include a QR code on the store's marketing materials, a shareable link, or a company directory/search
- **Customer UI**: A separate product browsing and cart experience (customers don't need to see inventory management, reports, or AI insights)
- **Push notifications to employees**: When a customer places an order, staff need to be alerted. This requires server-side logic (Supabase Edge Functions, or a backend service) — can't be done purely client-side
- **Multi-company awareness**: The customer side inherently needs to know about multiple companies, even if each store only sees its own data
- **Delivery/pickup coordination**: Customer needs status updates (order confirmed, ready for pickup, out for delivery)

### Implementation Options
1. **Separate Flutter app**: A "Customer" app alongside the current "Business" app, sharing the same Supabase backend
2. **Web storefront**: A lightweight web app (Flutter Web or React) that customers access via a link — no download required
3. **Dual-mode in the same app**: A "Customer Mode" login path within the existing app — simplest to deploy but adds UI complexity

### When to Build
After the main business app is fully deployed and being used by real stores. The internal order management from Phase 4 (Option A) covers the academic objective. Option B is a commercial enhancement for when a store wants to accept orders digitally from their customer base.

### What's Already In Place
- `companyId` on all data means the backend already supports multi-tenancy
- Supabase real-time subscriptions could power live order notifications
- The `orders` and `order_items` tables from Phase 4 would be reused — customer-placed orders would just have a different `createdBy` source

---

## Phase Dependency Diagram

```
Phase 1 (Bug Fixes)
  │
  ├──► Phase 2 (Security) ──► Phase 7 (Supabase Hardening)
  │
  ├──► Phase 3 (Sales Upgrade) ──► Phase 4 (Order Tracking)
  │
  ├──► Phase 5 (UX Enhancements)
  │
  └──► Phase 6 (Advanced AI)
```

Phases 3, 5, and 6 can be worked on in any order after Phase 1. Phase 4 requires Phase 3. Phase 7 requires Phase 2 and ideally all other phases (so we secure everything at once).

---

## Estimated Scope Per Phase

| Phase | New Files | Modified Files | New Packages | Complexity |
|-------|-----------|---------------|-------------|------------|
| 1 | 0 | 3-5 | 0 | Low |
| 2 | 2-3 | 6-8 | 2 (`crypto`, `flutter_secure_storage`) | Medium |
| 3 | 2-3 | 3-4 | 0 | Medium |
| 4 | 4-5 | 4-5 | 0 | High |
| 5 | 0-1 | 4-5 | 1 (`fl_chart`) | Low-Medium |
| 6 | 1-2 | 3-4 | 0 | Medium-High |
| 7 | 2-3 | 4-6 | 1 (`flutter_dotenv`) | High |

---

*Plan created April 8, 2026. Ready to export each phase as its own .md and begin implementation.*
