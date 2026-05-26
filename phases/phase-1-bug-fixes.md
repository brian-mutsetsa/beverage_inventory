# Phase 1: Bug Fixes & Verification

**Status**: IN PROGRESS (Steps 1.1–1.3 complete, Step 1.4 tested — user-reported issues fixed)
**Depends on**: Nothing — this is the starting point
**Complexity**: Low
**New files**: 0 | **Modified files**: 7 | **New packages**: 0

---

## Goal
Make sure the existing app is 100% stable before adding anything new. Any bugs in the foundation will cascade into new features.

---

## Steps

### Step 1.1 — Verify String Interpolation Bugs
The Progress Report flagged several escaped `$` bugs marked "FIXING NOW." We need to verify each one is actually fixed.

**Files to check:**
- `lib/screens/manager_auth_screen.dart`
  - companyId generation: `company_\${DateTime...}` → should be `company_${DateTime...}`
  - Success dialog: `Your company "\$companyName"` → should be `Your company "$companyName"`
- `lib/services/ai_service.dart`
  - Error message: `Error training model: \$e` → should be `Error training model: $e`
- `lib/screens/ai_detailed_forecast_screen.dart`
  - Forecast values: `\${product.quantity}` → should be `${product.quantity}`

**Actions:**
1. Open each file and search for `\$` (backslash-dollar)
2. Fix any escaped interpolation that should be live interpolation
3. Search the entire codebase (`lib/` folder) for any other `\$` occurrences that look wrong

**Tracking:**
- [x] `manager_auth_screen.dart` — companyId generation verified/fixed
- [x] `manager_auth_screen.dart` — success dialog verified/fixed
- [x] `ai_service.dart` — error message verified/fixed
- [x] `ai_detailed_forecast_screen.dart` — forecast values verified/fixed
- [x] Full codebase scan for other escaped `$` issues — done

> **Result**: All interpolation bugs from the Progress Report were already fixed. Full `lib/` grep for `\$` found only legitimate dollar-sign literals (e.g. `'\$${value}'` → `$123.45`). No changes needed.

---

### Step 1.2 — Remove or Integrate Deprecated Setup Screen
`lib/screens/setup_screen.dart` appears to be an older alternative to `manager_auth_screen.dart` and is not referenced in any navigation flow.

**Actions:**
1. Search the entire codebase for any reference to `setup_screen.dart` or `SetupScreen`
2. If unused: delete the file
3. If partially used: consolidate its functionality into `manager_auth_screen.dart`

**Tracking:**
- [x] Searched for references to `SetupScreen`
- [x] Decision made: remove / consolidate
- [x] Action taken (file deleted or merged)

> **Result**: `setup_screen.dart` was only referenced by itself (no imports anywhere). File deleted.

---

### Step 1.3 — Verify All Database Queries Filter by companyId
Quick sanity check that all DB queries are properly scoped. Single-company focus, so this is low-risk.

**Actions:**
1. Quick scan of `database_helper.dart` — confirm all queries include `companyId`
2. Check `readProduct(id)` — does it also verify companyId?
3. Check `deleteProduct(id)` — does it verify companyId?
4. Check `deleteSale(id)` — does it verify companyId?

**Tracking:**
- [x] All query methods scanned
- [x] `readProduct(id)` reviewed — **FIXED**: added `AND companyId = ?` filter
- [x] `deleteProduct(id)` reviewed — **FIXED**: added `AND companyId = ?` filter
- [x] `deleteSale(id)` reviewed — **FIXED**: added `AND companyId = ?` filter
- [x] Any issues found — fixed

> **Result**: All other query/report methods already filtered by `companyId`. The three single-record methods (`readProduct`, `deleteProduct`, `deleteSale`) were missing the filter and have been patched. `flutter analyze` passes with no errors.

---

### Step 1.4 — Test the Full App Flow
Run through the entire app manually to confirm everything works end-to-end.

> No multi-company or company-switching testing needed. Single company per device.

**Test checklist:**
- [x] Fresh install → Tutorial screens display correctly
- [x] Register company → companyId generated, manager PIN generated
- [x] Login with generated PIN → Reaches dashboard
- [x] Load demo data → 10 products, 5 staff, 30+ days of sales appear
- [x] Dashboard shows correct stats (product count, inventory value, low stock)
- [x] AI Insights widget displays on dashboard (manager view)
- [x] Record a sale → Stock decremented
- [x] Add a new product → Appears in inventory list
- [x] Edit a product → Changes saved
- [x] Delete a product (as manager) → Confirmation dialog → Product removed
- [x] Login as staff → Restricted access confirmed:
  - [x] Staff cannot add, edit, or delete products (view-only)
  - [x] No Employee Performance tab in reports
  - [x] No Profit Analysis tab in reports
  - [x] No AI Insights on dashboard
- [x] AI detailed forecast screen → Numbers display correctly (not literal `${variable}`)
- [x] Reports tab → Sales/Inventory tabs display data with enhanced breakdown
- [ ] Export a PDF report → Downloads/prints correctly *(not yet tested)*
- [ ] Clear all data → Everything resets except manager account *(not yet tested)*

---

## Definition of Done
All items above are checked off. The app is stable and clean — ready for Phase 2.

---

## Issues Found During This Phase
*(Log any unexpected issues here as they arise)*

| # | Issue | File(s) | Status |
|---|-------|---------|--------|
| 1 | `readProduct(id)` missing companyId filter | `database_helper.dart` | FIXED |
| 2 | `deleteProduct(id)` missing companyId filter | `database_helper.dart` | FIXED |
| 3 | `deleteSale(id)` missing companyId filter | `database_helper.dart` | FIXED |
| 4 | `setup_screen.dart` unused/deprecated | `setup_screen.dart` | DELETED |
| 5 | Recent sales section on checkout page removed (redundant with Reports) | `sales_screen.dart` | FIXED |
| 6 | Category field was free text — changed to dropdown with predefined list | `add_product_screen.dart` | FIXED |
| 7 | Staff could add/edit/delete products — now view-only for non-managers | `inventory_screen.dart` | FIXED |
| 8 | Order buttons in low-stock section did nothing — now logs audit + snackbar | `dashboard_screen.dart` | FIXED |
| 9 | Search only matched product name — now searches name, category, supplier, price | `inventory_screen.dart` | FIXED |
| 10 | Inventory report was basic — added Stock Health, Top Sellers, Slow Movers sections | `reports_screen.dart`, `database_helper.dart` | FIXED |
| 11 | Demo data March dates — expected behavior (30-day window from demo install) | N/A | NOT A BUG |

---

## Phase Sign-Off
- [ ] All steps completed
- [ ] All tests passed
- [ ] No blocking issues remaining
- [ ] Ready to proceed to Phase 2
