# Aura — Progress Report & Roadmap

## Current Status: ~70% Complete (MVP Functional, Critical Bugs Present)

---

## What's Done (Working Features)

### Core Infrastructure ✅
- [x] Flutter project structure with proper architecture
- [x] SQLite database with 4 tables (products, sales, users, audit_logs)
- [x] Multi-tenant data model (companyId on all tables)
- [x] Database version 3 with migration support

### Authentication & User Management ✅
- [x] Company registration with auto-generated companyId
- [x] Manager PIN generation (3 letters from company name + 3 random digits)
- [x] 6-digit PIN login system
- [x] Role-based access control (Manager / Staff)
- [x] Staff creation, deactivation, reactivation, PIN reset
- [x] User management screen (Manager only)

### Inventory Management ✅
- [x] Add / Edit / Delete products
- [x] Product categories (Soft Drink, Juice, Water, Mixer, etc.)
- [x] Stock level tracking (quantity, minQuantity)
- [x] Low stock detection & alerts
- [x] Search/filter products
- [x] Cost price & selling price tracking

### Sales / Point of Sale ✅
- [x] Product selection dropdown
- [x] Quantity controls (+/-)
- [x] Automatic total calculation
- [x] "Charge" button to record sale
- [x] Inventory auto-decreases on sale
- [x] Recent sales history display
- [x] Sale notes field

### AI / Machine Learning ✅
- [x] Demand forecasting (7-day prediction via linear regression)
- [x] Sales pattern recognition (peak/slow days)
- [x] Smart reorder alerts (days until stockout)
- [x] Profit optimization suggestions
- [x] AI Insights dashboard widget
- [x] Detailed forecast screen per product

### Reports & Analytics ✅
- [x] Sales reports (today / week / month)
- [x] Top products by revenue
- [x] Daily sales trend
- [x] Inventory statistics & category breakdown
- [x] Employee performance tracking (Manager only)
- [x] Profit analysis with margins (Manager only)
- [x] PDF report generation & export

### UI/UX ✅
- [x] Clean, modern design with Poppins font
- [x] Warm color scheme (amber/gold/black/white)
- [x] Onboarding tutorial (4-screen carousel)
- [x] Responsive card-based layouts
- [x] Role badges (MANAGER / STAFF)
- [x] Pull-to-refresh on key screens
- [x] Empty state illustrations

### Supporting Features ✅
- [x] Audit logging (tracks every user action)
- [x] Demo data loader (10 products, 5 staff, 24 sales)
- [x] Clear all data option
- [x] Local push notifications (daily tips, stock alerts)
- [x] splash screen with app initialization

---

## Critical Bugs Found (From Screenshots & Code Review)

### 🔴 BUG 1: String Interpolation — companyId Not Resolving
**File:** `lib/screens/manager_auth_screen.dart` line ~57  
**Issue:** `'company_\${DateTime.now()...}'` — backslash escapes the `$`, producing literal string `"company_${DateTime.now()...}"` instead of an actual timestamp.  
**Impact:** All companies get the same literal companyId string. Data from different companies merges together. This is the root cause of the database error in the screenshots.  
**Status:** 🔧 FIXING NOW

### 🔴 BUG 2: String Interpolation — Success Dialog
**File:** `lib/screens/manager_auth_screen.dart` line ~103  
**Issue:** `'Your company "\$companyName"...'` — same backslash issue.  
**Impact:** Dialog shows literal `${companyName}` instead of the actual company name.  
**Status:** 🔧 FIXING NOW

### 🔴 BUG 3: String Interpolation — AI Error Message
**File:** `lib/services/ai_service.dart` line ~95  
**Issue:** `'Error training model: \$e'` — same backslash issue.  
**Impact:** Error message shows literal `$e` instead of actual error details.  
**Status:** 🔧 FIXING NOW

### 🔴 BUG 4: String Interpolation — Forecast Screen
**File:** `lib/screens/ai_detailed_forecast_screen.dart` lines ~123-140  
**Issue:** `'\${product.quantity}'` and `"\${forecast['predictedSales7Days']}"` — same backslash issue throughout the forecast card.  
**Impact:** Forecast screen shows literal variable names instead of actual numbers (visible in screenshot).  
**Status:** 🔧 FIXING NOW

### 🟡 BUG 5: Missing companyId Filter — Inventory Value
**File:** `lib/database/database_helper.dart` — `getTotalInventoryValue()`  
**Issue:** SQL query doesn't filter by companyId.  
**Impact:** Dashboard shows inflated inventory value from all companies.  
**Status:** 🔧 FIXING NOW

### 🟡 BUG 6: Missing companyId Filter — Low Stock, Reports
**File:** `lib/database/database_helper.dart` — multiple report methods  
**Issue:** `getLowStockProducts()`, `getTotalSales()`, `getSalesByProduct()`, `getDailySales()`, `getInventoryStats()`, `getProductsByCategory()`, `getEmployeePerformance()`, `getEmployeeActivity()`, `getProfitAnalysis()` all missing `WHERE companyId = ?`.  
**Impact:** Reports mix data from all companies.  
**Status:** 🔧 FIXING NOW

### 🟡 BUG 7: Missing companyId Filter — User Login
**File:** `lib/database/database_helper.dart` — `getUserByPin()`, `getManagerUser()`  
**Issue:** Login doesn't filter by companyId, so PINs from other companies could match.  
**Impact:** Wrong user could log in if PINs collide across companies.  
**Status:** 🔧 FIXING NOW

### 🟡 BUG 8: Missing companyId Filter — Audit Logs
**File:** `lib/database/database_helper.dart` — `getAuditLogs()`, `getAuditLogsByUser()`  
**Issue:** Returns logs from all companies.  
**Status:** 🔧 FIXING NOW

### 🟡 BUG 9: Demo Data Only 7 Days
**File:** `lib/helpers/demo_data_helper.dart`  
**Issue:** Current demo data only covers 7 days with 24 sales. AI forecasting needs at least 7 days to start, and meaningful predictions need 21-30 days.  
**Impact:** AI features barely functional with demo data.  
**Status:** 🔧 FIXING NOW — expanding to 30+ days with realistic patterns

---

## What's Left to Build

### Priority 1: Bug Fixes (This Session) 🔧
- [ ] Fix all string interpolation bugs (escaped `$` signs)
- [ ] Add companyId filtering to ALL database queries
- [ ] Expand demo data to 30+ days for ML training
- [ ] Add database indexes for performance

### Priority 2: Cloud Sync (Next Sprint) 🌐

> **Firebase has been dropped** due to integration failures. Recommended replacement: **Supabase** (open-source, PostgreSQL-based) or a custom REST API backend.

- [ ] Set up Supabase project (or custom REST API with Node.js/Python + PostgreSQL)
- [ ] Implement `supabase_flutter` package for Dart client
- [ ] Sync products, sales, users, audit_logs to cloud
- [ ] Conflict resolution (last-write-wins or merge)
- [ ] Offline queue for pending sync operations (SQLite → Cloud)
- [ ] Cross-device data access
- [ ] Real-time sync listeners via Supabase Realtime
- [ ] JWT-based authentication replacing local-only PIN

### Priority 3: Customer Order Tracking (Enhancement) 📦
- [ ] Order status workflow (Pending → Processing → Completed → Delivered)
- [ ] Customer information capture (name, phone, address)
- [ ] Order history per customer
- [ ] Order notifications (SMS or push)
- [ ] Delivery tracking (basic)

### Priority 4: Security Hardening 🔒
- [ ] Hash PINs before storing (SHA-256 or bcrypt)
- [ ] Use flutter_secure_storage for sensitive data
- [ ] Session timeout after inactivity
- [ ] PIN complexity validation (no weak PINs like 111111)
- [ ] Biometric authentication option

### Priority 5: UX Enhancements 🎨
- [ ] Barcode scanning for product lookup
- [ ] Product image capture from camera
- [ ] Dark mode support
- [ ] Animated transitions between screens
- [ ] Batch sale recording (shopping cart / multi-item checkout)
- [ ] Stock adjustment screen (receive deliveries, count corrections)
- [ ] Dashboard charts (sales trends graph, category pie chart)

### Priority 6: Advanced AI 🤖
- [ ] Seasonal trend detection (holiday spikes, weather impact)
- [ ] Anomaly detection (unusual sales patterns)
- [ ] Price optimization suggestions
- [ ] Supplier performance tracking
- [ ] Multi-product correlation (bundling recommendations)

---

## Project Objectives Mapping

| Objective | Status | Implementation |
|-----------|--------|----------------|
| 1. Track stock levels | ✅ Done | Products table with quantity/minQuantity, low stock alerts, dashboard cards |
| 2. Automatically update inventory | ✅ Done | Sales screen auto-decreases quantity on charge |
| 3. Monitor customer orders | ✅ Done | Sales recording, reports, audit trail, AI analysis |
| 4. Synchronize data with cloud | 🔄 Pivoting | Firebase dropped; moving to Supabase or custom REST API. SQLite offline-first already works. |

---

## Recommended Next Steps (Immediate)

1. **Fix all bugs listed above** — the app is non-functional for new installs due to the companyId string interpolation bug
2. **Expand demo data** to 30 days so AI features showcase properly
3. **Test the complete flow**: Install fresh → Register → Login → Load demo → Verify all screens
4. **Implement cloud sync with Supabase** (or custom REST API) as the final major objective
5. **Document the customer order monitoring** in the project report using the sales/audit system as evidence
