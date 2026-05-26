# Phase 4: Customer Order Tracking (Internal — Option A)

**Status**: NOT STARTED
**Depends on**: Phase 3 (Sales & Checkout Upgrade)
**Complexity**: High
**New files**: 4-5 | **Modified files**: 4-5 | **New packages**: 0

---

## Goal
Add an internal order management workflow where **employees** create and track orders on behalf of customers (walk-ins, phone calls). Customers never interact with the app directly. This satisfies the academic objective "monitor customer orders."

> **Scope**: Internal only (Option A). Customer-facing ordering (Option B) is a future expansion documented separately in the Implementation Plan.

---

## Steps

### Step 4.1 — Data Model
Create the order infrastructure in the database.

**Actions:**

1. **Create Order model** — `lib/models/order.dart`:
   - `id` (int?, auto-increment)
   - `companyId` (String)
   - `customerName` (String, required)
   - `customerPhone` (String?, optional)
   - `customerAddress` (String?, optional)
   - `status` (String: `pending` | `processing` | `completed` | `delivered` | `cancelled`)
   - `totalAmount` (double)
   - `notes` (String?, optional)
   - `createdAt` (String, ISO timestamp)
   - `updatedAt` (String, ISO timestamp)
   - `createdBy` (int, userId of employee who created it)
   - Include: `toMap()`, `fromMap()`, `copyWith()`
   - [ ] Model created with all fields
   - [ ] `toMap()` and `fromMap()` work correctly

2. **Create OrderItem model** — `lib/models/order_item.dart`:
   - `id` (int?, auto-increment)
   - `orderId` (int, foreign key to orders)
   - `productId` (int)
   - `productName` (String)
   - `quantity` (int)
   - `unitPrice` (double)
   - `lineTotal` (double)
   - Include: `toMap()`, `fromMap()`
   - [ ] Model created with all fields

3. **Add database tables** — In `database_helper.dart`:
   - Create `orders` table:
     ```sql
     orders (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       companyId TEXT NOT NULL,
       customerName TEXT NOT NULL,
       customerPhone TEXT,
       customerAddress TEXT,
       status TEXT NOT NULL DEFAULT 'pending',
       totalAmount REAL NOT NULL,
       notes TEXT,
       createdAt TEXT NOT NULL,
       updatedAt TEXT NOT NULL,
       createdBy INTEGER NOT NULL
     )
     ```
   - Create `order_items` table:
     ```sql
     order_items (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       orderId INTEGER NOT NULL,
       productId INTEGER NOT NULL,
       productName TEXT NOT NULL,
       quantity INTEGER NOT NULL,
       unitPrice REAL NOT NULL,
       lineTotal REAL NOT NULL,
       FOREIGN KEY (orderId) REFERENCES orders(id)
     )
     ```
   - Add indexes: `idx_orders_companyId`, `idx_orders_status`, `idx_order_items_orderId`
   - [ ] Tables created in `_createDB()`
   - [ ] Indexes added
   - [ ] Database version bumped to 4
   - [ ] Migration in `_onUpgrade()` handles v3 → v4

4. **Add CRUD methods** — In `database_helper.dart`:
   - `createOrder(Order order, List<OrderItem> items)` — inserts order + all items in transaction
   - `getOrders({String? status})` — list orders filtered by companyId, optionally by status
   - `getOrderById(int id)` — returns order with its items
   - `updateOrderStatus(int orderId, String newStatus)` — updates status and `updatedAt`
   - `getOrdersByCustomer(String phone)` — find orders by customer phone
   - `getOrderCount({String? status})` — count orders, optionally by status
   - [ ] `createOrder()` implemented (transactional)
   - [ ] `getOrders()` implemented with status filter
   - [ ] `getOrderById()` returns order + items
   - [ ] `updateOrderStatus()` implemented
   - [ ] `getOrdersByCustomer()` implemented
   - [ ] `getOrderCount()` implemented
   - [ ] All methods filter by `currentCompanyId`

---

### Step 4.2 — Order Creation Screen
Allow employees to create orders from the cart (alternative to immediate "Charge").

**Actions:**

1. **Create order screen** — `lib/screens/create_order_screen.dart`:
   - **Customer info section**:
     - Customer name (required, text field)
     - Customer phone (optional, phone keyboard)
     - Customer address (optional, text field)
   - **Items section**:
     - Reuse the cart component / pattern from Phase 3
     - Product selector + quantity + "Add" button
     - Cart list with editable quantities and remove buttons
     - Line totals and grand total
   - **Notes field**: Optional text area for special instructions
   - **"Place Order" button**:
     - Validates: customer name present, at least 1 item
     - Creates `Order` with status `pending`
     - Creates all `OrderItem` records
     - Does **NOT** decrement stock (stock changes when order moves to `processing`)
     - Logs audit: action = `create_order`
     - Shows success dialog with order number
   - [ ] Screen created with all form sections
   - [ ] Customer info form works
   - [ ] Cart/items component integrated
   - [ ] Validation works
   - [ ] Order saved to DB with status `pending`
   - [ ] Stock NOT changed on order creation
   - [ ] Audit log entry created

2. **Integration with sales screen**:
   - Add a secondary button on `sales_screen.dart`: "Place Order" alongside "Charge All"
   - "Charge All" = immediate sale (as in Phase 3)
   - "Place Order" = navigates to create order screen, optionally pre-filling cart items
   - [ ] "Place Order" button added to sales screen
   - [ ] Navigation to create order screen works

---

### Step 4.3 — Order Management Screen
View and manage all orders through their lifecycle.

**Actions:**

1. **Create orders list screen** — `lib/screens/orders_screen.dart`:
   - **Filter tabs** at top: All | Pending | Processing | Completed | Delivered
   - **Order cards** for each order:
     - Customer name (bold)
     - Item count + total amount
     - Status badge (color-coded):
       - Pending → orange
       - Processing → blue
       - Completed → green
       - Delivered → grey
       - Cancelled → red
     - Date created
     - Tap → navigate to order detail
   - **Search**: Filter by customer name or phone
   - **Empty state**: "No orders yet" with helpful message
   - **Pull-to-refresh**
   - [ ] Screen created with tab filter
   - [ ] Order cards display correctly
   - [ ] Status badges color-coded
   - [ ] Search works
   - [ ] Tap navigates to detail

2. **Create order detail screen** — `lib/screens/order_detail_screen.dart`:
   - **Customer section**: Name, phone, address
   - **Items list**: Product name, quantity, unit price, line total for each item
   - **Order total**: Grand total
   - **Timestamps**: Created at, last updated
   - **Created by**: Employee name who placed the order
   - **Status section** with action buttons:
     - If `pending`:
       - "Start Processing" button → changes to `processing`, **decrements stock for all items**
       - "Cancel Order" button → changes to `cancelled`, no stock change
     - If `processing`:
       - "Mark Completed" button → changes to `completed`
       - "Cancel Order" button → changes to `cancelled`, **restores stock for all items**
     - If `completed`:
       - "Mark Delivered" button → changes to `delivered`
     - If `delivered` or `cancelled`:
       - No action buttons (final states)
   - **Notes**: Display order notes if any
   - [ ] Screen created with all sections
   - [ ] Customer and item info displays correctly
   - [ ] Status buttons appear based on current status
   - [ ] "Start Processing" decrements stock
   - [ ] "Cancel" restores stock if order was in `processing`
   - [ ] "Cancel" does nothing to stock if order was `pending`
   - [ ] Status updates saved to DB
   - [ ] Audit log on every status change

3. **Navigation integration**:
   - Option A: Add "Orders" as a quick action on the dashboard
   - Option B: Add "Orders" as a 5th tab in bottom navigation
   - Decision: TBD during implementation (depends on UI fit)
   - [ ] Orders screen accessible from dashboard or nav
   - [ ] Order count badge on the entry point (pending orders count)

---

### Step 4.4 — Customer History
Allow looking up a customer's past orders by phone number.

**Actions:**

1. **Customer search on orders screen**:
   - When searching by phone number, show "View all orders for this customer" option
   - Displays filtered list: all orders from that phone number, sorted by date
   - Shows total amount across all orders
   - [ ] Customer lookup by phone works
   - [ ] Shows all orders from that customer

---

### Step 4.5 — Supabase Sync for Orders
Extend cloud sync to cover the new order tables.

**Actions:**

1. **Supabase schema** — Add to `supabase-setup.md` and run in Supabase:
   - `orders` table matching local schema + `local_id`, `synced_at`
   - `order_items` table matching local schema + `local_id`, `synced_at`
   - Indexes on `company_id`, `status`
   - RLS policies (matching existing pattern)
   - [ ] SQL migration script added
   - [ ] Tables created in Supabase

2. **Update supabase_service.dart**:
   - `upsertOrder()`, `getOrders(companyId)`, `deleteOrder()`
   - `upsertOrderItem()`, `getOrderItems(orderId)`
   - [ ] CRUD methods for orders added
   - [ ] CRUD methods for order_items added

3. **Update sync_service.dart**:
   - `pushOrder()` — push on create and status update
   - `pushOrderItems()` — push items when order created
   - `fullSync()` — include orders and order_items tables
   - Real-time listener for orders table
   - [ ] Push methods added
   - [ ] Full sync includes orders
   - [ ] Real-time listener active

---

### Step 4.6 — Testing

**Order Creation:**
- [ ] Create order: customer name + 3 items → Status = `pending`
- [ ] Stock NOT changed after order creation
- [ ] Audit log has `create_order` entry
- [ ] Order appears in orders list under "Pending" tab

**Order Lifecycle:**
- [ ] Pending → "Start Processing" → Status = `processing`, stock decremented for all items
- [ ] Processing → "Mark Completed" → Status = `completed`, no stock change
- [ ] Completed → "Mark Delivered" → Status = `delivered`, no stock change
- [ ] Verify stock: total decrement matches order quantities

**Order Cancellation:**
- [ ] Cancel a `pending` order → Status = `cancelled`, stock NOT changed
- [ ] Cancel a `processing` order → Status = `cancelled`, stock RESTORED
- [ ] Cancelled orders show with red badge

**Customer History:**
- [ ] Create 3 orders for same phone number
- [ ] Search by phone → All 3 orders shown
- [ ] Orders sorted by date (newest first)

**Cloud Sync:**
- [ ] Create order → Appears in Supabase
- [ ] Update order status → Synced to Supabase
- [ ] Full sync pulls orders from cloud → Appears locally

---

## Definition of Done
Full order lifecycle works (create → process → complete → deliver/cancel), customer history lookup works, stock management tied to order status transitions, cloud sync covers orders.

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
- [ ] Ready to proceed to Phase 5
