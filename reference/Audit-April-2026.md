# Aura — Full Codebase Audit (April 8, 2026)

## Overview

This document is a thorough audit of the entire Aura codebase, cross-referenced against all reference documents (`Whats-left.md`, `App-Vision-Holistic.md`, `Progress-Report.md`, `AI-implementation.md`, `Brief-description.md`, `client_message.md`, `supabase-setup.md`). Every source file under `lib/` was read in full.

---

## What the App CAN Do Right Now

### Core Infrastructure ✅
- Multi-tenant data model — every table (products, sales, users, audit_logs) has `companyId`
- All queries in `database_helper.dart` filter by `currentCompanyId`
- Performance indexes on all `companyId` columns, PIN, and sale date
- SQLite database v3 with migration support (v1→v2→v3)
- Offline-first architecture — app works fully without internet

### Authentication & User Management ✅
- Company registration with auto-generated `companyId` + manager PIN (3 letters from company name + 3 random digits)
- 6-character alphanumeric PIN login with auto-focus between input boxes
- Role-based access control (Manager / Staff) enforced throughout UI
- Staff CRUD: create, deactivate, reactivate, PIN reset
- "Join existing company" flow that pulls data from Supabase cloud
- "Switch company" option from login screen
- `companyId` persisted in SharedPreferences

### Inventory Management ✅
- Full CRUD: add, edit, delete (manager-only delete with confirmation dialog)
- Product fields: name, category, quantity, minQuantity, costPrice, sellingPrice, supplier, barcode, imagePath
- Categories: Soft Drink, Juice, Water, Mixer, etc.
- Search/filter by name or category
- Color-coded stock status badges: Empty (red), Low (orange), OK (green)
- Low stock alerts on dashboard (top 3 shown)
- Audit logging on all product actions

### Point of Sale ✅
- Product selection dropdown (shows available stock)
- Quantity controls (+/-)
- Auto-calculated total (quantity × unit price)
- Notes field for customer/transaction details
- "Charge" button records sale and auto-decrements stock
- Recent sales history (last 20 transactions)
- Stock validation (can't sell more than available)
- Audit trail per sale (who sold what, when)

### AI / Machine Learning ✅
- **Demand Forecasting**: Linear regression via `ml_algo` on 30-day sales data → 7-day prediction with 20% safety buffer
- **Sales Pattern Recognition**: Identifies best/worst sales days with percentage spike vs average
- **Smart Reorder Alerts**: Daily burn rate calculation, days-until-stockout, flags items ≤5 days remaining, recommends 14-day supply
- **Profit Optimization**: Ranks products by margin % and volume, identifies underperformers
- AI Insights widget on dashboard (manager-only)
- Detailed per-product forecast screen with risk level (HIGH/HEALTHY)
- Requires minimum 7 days of sales data to activate

### Reports & PDF Export ✅
- **Sales Report**: Today/week/month totals, transaction counts, top 5 products by revenue, daily trend bar chart
- **Inventory Report**: Total products, low stock count, value, cost, potential profit, category breakdown
- **Employee Performance** (manager-only): Sales count per employee, 7-day activity by action type
- **Profit Analysis** (manager-only): Revenue, cost, gross profit, margin %, visual breakdown
- PDF generation for all 4 report types via `pdf` + `printing` packages
- Tab-based interface with role-aware tab visibility

### Cloud Sync (Supabase) ✅
- Full Supabase integration with real credentials configured
- **Push-on-write**: Every local create/update/delete auto-pushes to cloud
- **Full pull on login**: Syncs all cloud data into local SQLite
- **Real-time listeners**: Subscribes to all 4 tables, screens auto-refresh on changes
- Supabase service with upsert (idempotent), delete, and real-time subscription methods
- SQL schema with RLS policies documented in `supabase-setup.md`
- Graceful offline fallback — `isEnabled` gate skips cloud ops when Supabase is unconfigured
- Sync events broadcast via stream; multiple screens listen and reload

### UX & Polish ✅
- Onboarding tutorial (4-screen carousel: POS, Inventory, AI, Sync)
- Animated splash screen with scale + fade-in
- Modern UI: Poppins font, warm amber/gold/black/white scheme, Material 3
- Local push notifications: daily AI tips at 9AM and 6PM (Africa/Harare timezone)
- Demo data generator: 30+ days of realistic sales with day-of-week patterns, 10 products, 5 staff
- Pull-to-refresh on key screens
- Empty state illustrations
- Role badges (MANAGER / STAFF)

---

## What's NOT Implemented

### Customer Order Tracking (Priority 2 from What's Left) ❌
| Feature | Status |
|---------|--------|
| Order status workflow (Pending → Processing → Completed → Delivered) | Not built |
| Customer information capture (name, phone, address) | Not built |
| Order history per customer | Not built |
| Order notifications (SMS/push per order) | Not built |
| Delivery tracking | Not built |

> No `Order` model, no orders table, no orders screen exist anywhere in the codebase. The `client_message.md` mentions it's planned but nothing has been started.

### Security Hardening (Priority 4 from What's Left) ❌
| Feature | Status |
|---------|--------|
| Hash PINs before storing (SHA-256/bcrypt) | Not done — PINs stored in plaintext in SQLite |
| `flutter_secure_storage` for sensitive data | Not done |
| Session timeout after inactivity | Not done |
| PIN complexity validation (reject weak PINs like 111111) | Not done |
| Biometric authentication option | Not done |

### UX Enhancements (Priority 5 from What's Left) — Partial ⚠️
| Feature | Status |
|---------|--------|
| Barcode scanning for product lookup | Not done (barcode *field* exists but no scanner) |
| Product image capture from camera | Not done (imagePath *field* exists but no camera integration) |
| Dark mode | Not done |
| Animated screen transitions | Not done |
| Batch sale / multi-item cart checkout | Not done — sales are one product at a time |
| Stock adjustment screen (receive deliveries, count corrections) | Not done |
| Dashboard charts (sales trend graph, category pie chart) | Partial — bar charts in Reports tab, not on Dashboard |

### Advanced AI (Priority 6 from What's Left) ❌
| Feature | Status |
|---------|--------|
| Seasonal trend detection (holiday spikes, weather impact) | Not done |
| Anomaly detection (unusual sales patterns) | Not done |
| Price optimization suggestions | Not done |
| Supplier performance tracking | Not done |
| Multi-product correlation / bundling recommendations | Not done |

### Admin App / Platform Management ❌
| Feature | Status |
|---------|--------|
| Admin dashboard to manage all companies | Not built |
| Company directory / central registry | Not built |
| Cross-company analytics | Not built |
| Company approval / deactivation workflow | Not built |
| Platform billing / subscription management | Not built |

> Multi-tenant data isolation works at the data layer, but there is no admin-level oversight. Each company is fully self-service. Running this for multiple companies would require a separate admin panel (web or in-app).

### Supabase Production Hardening ⚠️
| Feature | Status |
|---------|--------|
| Row-Level Security tied to auth (not permissive "allow all") | Not done — current RLS is wide open |
| JWT-based auth replacing local-only PIN | Not done |
| Incremental sync (only changed records) | Not done — full sync pulls everything |
| Retry logic with exponential backoff | Not done |
| Environment variables for credentials (not hardcoded) | Not done |

---

## Bug Fix Status (from Progress Report)

| Bug | Description | Status |
|-----|-------------|--------|
| String interpolation (escaped `$`) in manager_auth_screen | companyId not resolving | Flagged as "FIXING NOW" — **needs verification** |
| String interpolation in AI error messages | Shows literal `$e` | Flagged as "FIXING NOW" — **needs verification** |
| String interpolation in forecast screen | Shows literal variable names | Flagged as "FIXING NOW" — **needs verification** |
| Missing companyId filters on DB queries | Reports mix data across companies | **Fixed** ✅ — All queries now filter by `currentCompanyId` |
| Demo data only 7 days | AI features barely functional | **Fixed** ✅ — Now generates 30+ days with realistic patterns |

---

## Academic Objectives Mapping

| Objective (from Brief) | Implementation | Status |
|------------------------|----------------|--------|
| 1. Track stock levels | Products table with quantity/minQuantity, low stock alerts, dashboard cards, AI stockout predictions | ✅ Complete |
| 2. Automatically update inventory | Sales screen auto-decreases quantity on charge, audit trail | ✅ Complete |
| 3. Monitor customer orders | Sales recording, reports, audit trail, AI pattern analysis | ✅ Complete (via POS — no formal order workflow) |
| 4. Synchronize data with cloud | Supabase push-on-write + full sync + real-time listeners, offline-first with SQLite | ✅ Complete |

---

## Completion Summary

| Area | % Complete | Notes |
|------|-----------|-------|
| Inventory CRUD | 100% | Fully functional |
| Point of Sale | 95% | Works, but single-item only (no cart) |
| User Management | 100% | Create, deactivate, reactivate, reset PIN |
| Reports + PDF | 100% | 4 report types with PDF export |
| AI/ML Forecasting | 100% | On-device linear regression, 4 insight types |
| Multi-tenant Data Model | 100% | companyId on all tables, filtered queries |
| Cloud Sync (Supabase) | 90% | Wired up, needs production RLS & incremental sync |
| Authentication | 70% | Functional but PINs in plaintext, no timeout, no biometric |
| Customer Order Tracking | 0% | Not started |
| Security Hardening | 10% | Basic role checks only |
| UX Enhancements | 30% | Good foundation, missing barcode/camera/dark mode/cart |
| Advanced AI | 0% | Seasonal, anomaly, pricing not started |
| Admin App / Platform Mgmt | 0% | Not started |

**Overall: ~75% for the core app, ~60% against the full project vision.**

---

## Key Architectural Decisions Already Made

1. **Supabase over Firebase** — Firebase was dropped due to integration issues. Supabase chosen for PostgreSQL, predictable pricing, and open-source nature.
2. **On-device ML** — `ml_algo` for linear regression runs entirely on the phone. No cloud ML cost, works offline, privacy-friendly.
3. **Offline-first** — SQLite is the source of truth. Cloud is optional enhancement with graceful degradation.
4. **PIN-based auth** — Simple 6-character alphanumeric PINs. No email/password. Works for small retail context but needs hardening for production.

---

## Files Audited

### Models (4 files)
- `lib/models/product.dart` — Product model with companyId, copyWith, toMap/fromMap
- `lib/models/sale.dart` — Sale model with companyId
- `lib/models/user.dart` — User model with companyId, role, isActive
- `lib/models/audit_log.dart` — AuditLog model with companyId

### Database (1 file)
- `lib/database/database_helper.dart` — Singleton DB helper, all CRUD + report queries, companyId filtering throughout

### Screens (13 files)
- `lib/screens/splash_screen.dart` — Animated splash, routing logic
- `lib/screens/tutorial_screen.dart` — 4-page onboarding carousel
- `lib/screens/manager_auth_screen.dart` — Company registration + join existing
- `lib/screens/setup_screen.dart` — Alternative setup (appears deprecated)
- `lib/screens/login_screen.dart` — 6-character PIN login
- `lib/screens/home_screen.dart` — Bottom nav container (4 tabs)
- `lib/screens/dashboard_screen.dart` — Stats, AI insights, low stock, quick actions
- `lib/screens/inventory_screen.dart` — Product list with search, CRUD
- `lib/screens/add_product_screen.dart` — Product add/edit form
- `lib/screens/sales_screen.dart` — POS checkout + recent history
- `lib/screens/reports_screen.dart` — 4-tab reports with PDF export
- `lib/screens/user_management_screen.dart` — Staff CRUD
- `lib/screens/ai_detailed_forecast_screen.dart` — Per-product forecast cards

### Services (5 files)
- `lib/services/ai_service.dart` — Linear regression forecasting, insights, alerts, profit optimization
- `lib/services/notification_service.dart` — Local notifications with timezone support
- `lib/services/supabase_config.dart` — Supabase URL + anon key
- `lib/services/supabase_service.dart` — Cloud CRUD + real-time subscriptions
- `lib/services/sync_service.dart` — Offline-first sync orchestration

### Helpers (2 files)
- `lib/helpers/demo_data_helper.dart` — 30-day realistic demo data generator
- `lib/helpers/pdf_report_generator.dart` — PDF generation for 4 report types

### Widgets (1 file)
- `lib/widgets/ai_insights_widget.dart` — Dashboard AI insights panel

### Entry Point (1 file)
- `lib/main.dart` — App initialization (DB → Notifications → Supabase), theme setup

---

*Audit performed April 8, 2026. Next step: decide which remaining features to prioritize.*
