# Phase 3: Sales & Checkout Upgrade

**Status**: NOT STARTED
**Depends on**: Phase 1 (Bug Fixes & Verification)
**Complexity**: Medium
**New files**: 2-3 | **Modified files**: 3-4 | **New packages**: 0

---

## Goal
Transform the single-item POS into a proper multi-item checkout with a shopping cart, add stock adjustment tools, and provide receipt views after checkout.

---

## Steps

### Step 3.1 — Multi-Item Cart (Batch Sales)
Currently sales are recorded one product at a time. We'll add a shopping cart so an employee can ring up multiple items in a single transaction.

**Actions:**

1. **Create CartItem model** — `lib/models/cart_item.dart`:
   - Fields: `product` (Product object), `quantity` (int), `unitPrice` (double), `lineTotal` (double, computed)
   - Method: `copyWith()` for quantity updates
   - [ ] Model created

2. **Cart state management** — Either a separate `cart_service.dart` or in-screen state in `sales_screen.dart`:
   - `List<CartItem> _cartItems` — the active cart
   - `addItem(Product product, int quantity)` — adds to cart or increments if already exists
   - `removeItem(int productId)` — removes from cart
   - `updateQuantity(int productId, int newQty)` — updates quantity for existing item
   - `clearCart()` — empties the cart
   - `getTotal()` → sum of all `lineTotal` values
   - `getItemCount()` → total number of distinct items
   - Validation: can't add more than available stock (across all cart items for the same product)
   - [ ] Cart logic implemented
   - [ ] Stock validation works (can't exceed available)

3. **Redesign sales_screen.dart UI**:
   - **Top section**: Product dropdown + quantity input + "Add to Cart" button
     - After adding, clears the selector and quantity for next item
   - **Middle section**: Scrollable cart list
     - Each row: product name, quantity (editable +/-), unit price, line total, remove (X) button
     - Empty state: "Cart is empty — add products above"
   - **Bottom section**: Fixed footer with:
     - Item count badge
     - Cart total (bold, large)
     - "Charge All" primary button
   - [ ] UI redesigned with three sections
   - [ ] Cart list renders correctly
   - [ ] Add/remove/update quantity from the cart list works

4. **"Charge All" logic**:
   - Validate: cart not empty
   - Validate: all quantities still available (stock may have changed since adding)
   - In a database transaction (all-or-nothing):
     - For each cart item: create a `Sale` record
     - For each cart item: decrement the product's `quantity`
     - For each cart item: log an `AuditLog` entry
   - On success: clear cart, show receipt (Step 3.3), refresh data
   - On failure: roll back, show error
   - [ ] Batch sale creates all Sale records
   - [ ] Stock decremented for each item
   - [ ] Audit logged for each item
   - [ ] Database transaction ensures all-or-nothing
   - [ ] Cart cleared after successful charge

5. **Keep Recent Sales section**:
   - Below the cart, keep the existing "Recent Sales" list (last 20)
   - Updates after each successful charge
   - [ ] Recent sales still displays below cart

---

### Step 3.2 — Stock Adjustment Screen
Managers need a way to add stock (received deliveries) and correct counts (physical inventory check) without going through the product edit form.

**Actions:**

1. **Create stock adjustment screen** — `lib/screens/stock_adjustment_screen.dart`:
   - **Product selector**: Dropdown listing all products (name + current qty shown)
   - **Adjustment type**: Radio buttons or toggle:
     - "Received Delivery" (always adds stock, positive only)
     - "Inventory Correction" (can be positive or negative)
   - **Quantity field**: Number input
     - For "Received Delivery": always positive
     - For "Inventory Correction": positive (found extra) or negative (found shortage)
   - **Reason/notes field**: Required text field explaining the adjustment
   - **"Apply" button**:
     - Updates product quantity in database
     - Logs audit trail: action = `stock_adjustment`, details include type, quantity, reason
     - Shows success snackbar with new stock level
   - [ ] Screen created with all form elements
   - [ ] "Received Delivery" mode works (positive only)
   - [ ] "Inventory Correction" mode works (positive or negative)
   - [ ] Reason field required
   - [ ] Product quantity updated in DB
   - [ ] Audit log entry created

2. **Add database method** — In `database_helper.dart`:
   - `adjustStock(int productId, int quantityDelta, String reason)`:
     - Reads current product quantity
     - Adds delta (can be negative for corrections)
     - Validates result >= 0 (can't go below zero)
     - Updates product quantity
     - Returns updated product
   - [ ] Method created
   - [ ] Validates non-negative result

3. **Dashboard integration**:
   - Add "Adjust Stock" as a quick action card on dashboard (manager only)
   - Routes to stock adjustment screen
   - [ ] Quick action added to dashboard

4. **Adjustment history view**:
   - On the stock adjustment screen, add a section showing recent adjustments
   - Query: `getAuditLogs()` filtered by action = `stock_adjustment`
   - Show: date, product, type, quantity, reason
   - [ ] History section displays recent adjustments

---

### Step 3.3 — Sale Receipt View
After a successful checkout, show a receipt-style summary that can optionally be printed.

**Actions:**

1. **Create receipt dialog/bottom sheet** — After "Charge All" succeeds:
   - **Header**: Company name, date/time
   - **Items table**: Product name | Qty | Unit Price | Line Total (for each cart item)
   - **Footer**: Subtotal, served by (employee name)
   - **Actions**: "Done" button (dismisses), "Print" button (optional)
   - [ ] Receipt dialog created
   - [ ] Displays all cart items with totals
   - [ ] Shows date/time and employee name

2. **Print receipt** (optional enhancement):
   - Use the `printing` package (already in dependencies)
   - Generate a small-format PDF matching the receipt layout
   - Trigger system print dialog
   - [ ] Print button generates PDF receipt
   - [ ] System print dialog opens

---

### Step 3.4 — Testing

**Multi-Item Cart:**
- [ ] Add 1 product to cart → Cart shows 1 item, correct total
- [ ] Add 2 more different products → Cart shows 3 items, correct total
- [ ] Add same product again → Quantity increments (not duplicate row)
- [ ] Change quantity via +/- buttons → Line total and cart total update
- [ ] Remove an item → Item gone, total recalculates
- [ ] "Charge All" → All 3 sales records created in DB
- [ ] Stock decremented correctly for each product
- [ ] Audit log has entries for each sale
- [ ] Cart is empty after successful charge
- [ ] Try adding more than available stock → Error message shown

**Stock Adjustment:**
- [ ] Select product with 20 units → "Received Delivery" +50 → Stock now 70
- [ ] "Inventory Correction" -5 → Stock now 65
- [ ] Try correction that would make stock negative → Error shown
- [ ] Reason field empty → Form doesn't submit
- [ ] Adjustment history shows the entries we just made
- [ ] Audit log records each adjustment

**Receipt:**
- [ ] Receipt shows after successful "Charge All"
- [ ] All items listed with correct quantities and prices
- [ ] Total matches cart total
- [ ] Employee name and date displayed
- [ ] "Done" dismisses the receipt
- [ ] "Print" generates a PDF (if implemented)

---

## Definition of Done
Multi-item checkout works end-to-end, stock adjustments work, receipts display correctly.

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
- [ ] Ready to proceed to Phase 4
