# Aura — AI-Powered Beverage Inventory Management System

## Holistic Application Vision

---

## 1. What Is Aura?

Aura is a **mobile-first, offline-capable, AI-powered supply chain management SaaS application** designed for small beverage businesses. It provides real-time inventory tracking, point-of-sale recording, AI-driven demand forecasting, and cloud synchronization — all accessible from a smartphone.

The name "Aura" reflects the idea of intelligent awareness around your business: the app anticipates what you need before you know you need it.

---

## 2. SaaS Architecture Overview

Aura operates as a **multi-tenant SaaS platform** where each registered business (store) is an isolated tenant:

```
┌──────────────────────────────────────────────────────────┐
│                    AURA PLATFORM (SaaS)                  │
│                                                          │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐         │
│  │  Store A   │  │  Store B   │  │  Store C   │  ...    │
│  │ (Siyaz)    │  │ (QuickMart)│  │ (FreshBev) │         │
│  │            │  │            │  │            │         │
│  │ Manager    │  │ Manager    │  │ Manager    │         │
│  │ Staff x5   │  │ Staff x3   │  │ Staff x8   │         │
│  │ Products   │  │ Products   │  │ Products   │         │
│  │ Sales      │  │ Sales      │  │ Sales      │         │
│  │ AI Models  │  │ AI Models  │  │ AI Models  │         │
│  └────────────┘  └────────────┘  └────────────┘         │
│                                                          │
│  ┌──────────────────────────────────────────────────┐    │
│  │             Supabase Cloud (Shared)                │    │
│  │  • Real-time sync   • Backup   • Cross-device    │    │
│  └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

### Key Multi-Tenant Principles
- **Data Isolation**: Every record (product, sale, user, audit log) is tagged with a `companyId`. No store can see another store's data.
- **One App, Many Stores**: A single APK can host any number of businesses. Each device registers to one company at a time but can switch.
- **Offline-First**: SQLite stores all data locally. The app works without internet. Cloud sync resumes when connectivity returns.

---

## 3. User Roles & Permissions

Aura supports a **two-tier role model**: **Manager** and **Staff**. Each role has specific capabilities designed around real retail workflows.

### 3.1 Manager (Store Owner / Admin)

The Manager is the store owner or primary administrator. They have full control over the store.

| Capability                    | Access |
|-------------------------------|--------|
| Register the store (first-time setup) | ✅ |
| Add / Edit / Delete products  | ✅ |
| Record sales                  | ✅ |
| View all reports (Sales, Inventory, Employee, Profit) | ✅ |
| View AI Insights & Forecasts  | ✅ |
| Create / Deactivate / Reset staff accounts | ✅ |
| Load / Clear demo data        | ✅ |
| Export PDF reports             | ✅ |
| View audit trail (who did what) | ✅ |
| Switch to a different company  | ✅ |

**Typical Workflow:**
1. Opens app → Dashboard shows store health at a glance
2. Checks AI Insights for demand trends and reorder alerts
3. Reviews low-stock warnings → taps "Order" to plan restocking
4. Checks Employee Performance to see who sold the most
5. Exports weekly Profit Analysis PDF for bookkeeping
6. Creates new staff accounts when hiring

### 3.2 Staff (Employee / Cashier)

Staff members are employees who handle day-to-day operations. Their access is intentionally limited to prevent accidental or unauthorized changes.

| Capability                    | Access |
|-------------------------------|--------|
| Log in with assigned PIN      | ✅ |
| Add / Edit products           | ✅ |
| Delete products               | ❌ |
| Record sales (point of sale)  | ✅ |
| View Sales & Inventory reports | ✅ |
| View Employee Performance     | ❌ |
| View Profit Analysis          | ❌ |
| View AI Insights              | ❌ |
| Manage other users            | ❌ |
| Access admin menu             | ❌ |

**Typical Workflow:**
1. Opens app → Dashboard shows product count and low-stock alerts
2. Customer arrives → switches to Sales tab
3. Selects product, enters quantity, taps "Charge"
4. Inventory auto-updates after each sale
5. Checks Inventory tab to restock shelves
6. At end of shift, reviews today's sales in Reports tab

### 3.3 Future Role: Customer (Not Yet Implemented)

In a future version, customers could:
- Browse a store's product catalog
- Place orders for pickup/delivery
- Track order status
- View order history

This would require a separate authentication flow (email/phone) and a customer-facing UI.

---

## 4. How a Store Operates in Aura

### 4.1 Store Registration Flow

```
Download App → Tutorial (4 screens) → Register Company
       │
       ├── Enter: Company Name (e.g., "Siyaz Beverages")
       ├── Enter: Manager Full Name (e.g., "Kelly Nxumalo")
       │
       ▼
   System Generates:
       ├── companyId: "company_1710876543210" (unique)
       ├── Manager PIN: "SIY332" (3 letters from company + 3 digits)
       │
       ▼
   Manager writes down PIN → Goes to Login Screen
```

### 4.2 Daily Operations

```
Morning Routine:
  Manager logs in → Checks Dashboard
       │
       ├── Reviews AI Insights (demand forecast, best/worst days)
       ├── Addresses Low Stock alerts (creates purchase orders)
       └── Shares daily priorities with staff

During the Day:
  Staff logs in → Records sales as customers buy
       │
       ├── Sales Screen: Select product → Set quantity → Charge
       ├── Inventory auto-decreases after each sale
       └── Audit log tracks who sold what

End of Day:
  Manager reviews Reports
       │
       ├── Total sales for today
       ├── Top-selling products
       ├── Employee performance
       ├── Exports PDF for records
       └── AI recommends what to reorder for tomorrow
```

### 4.3 Inventory Lifecycle

```
Product Added → Stock Level Monitored → Sale Recorded → Quantity Decreases
       │                │                                        │
       │          If quantity ≤ minQuantity                       │
       │                │                                        │
       │          LOW STOCK ALERT                                │
       │          AI predicts stockout date                      │
       │          Recommends reorder quantity                    │
       │                │                                        │
       │          Manager reorders → Updates stock               │
       └────────────────┴────────────────────────────────────────┘
```

---

## 5. AI / Machine Learning Features

Aura uses **on-device ML** (no cloud required) powered by linear regression models.

### 5.1 Demand Forecasting
- Analyzes the last 30 days of sales per product
- Predicts next 7 days of demand
- Recommends order quantities (with 20% safety buffer)
- Classifies risk: HIGH (will run out) vs HEALTHY (sufficient stock)
- **Requires**: Minimum 7 days of sales data

### 5.2 Sales Pattern Recognition
- Identifies peak sales day (e.g., "Friday is +35% above average")
- Identifies slow days (e.g., "Monday is weakest")
- Helps managers plan staffing and promotions

### 5.3 Smart Reorder Alerts
- Calculates daily burn rate per product
- Estimates days until stockout
- Alerts when a product has ≤ 5 days of stock remaining
- Recommends 14-day supply reorder

### 5.4 Profit Optimization
- Ranks products by profit margin
- Ranks by sales volume
- Recommends focusing on high-margin, high-volume items
- Identifies underperforming products for potential discontinuation

---

## 6. Data Synchronization Strategy

### Current: Offline-First with SQLite
- All data lives in local SQLite database
- App works completely offline
- No data loss if phone has no signal

### Planned: Cloud Sync (Supabase or Custom REST API)

> **Note:** Firebase was initially planned but has been dropped due to integration issues. The recommended replacement is **Supabase** (open-source Firebase alternative with PostgreSQL) or a **custom REST API** (Node.js/Python + PostgreSQL/MySQL).

- Real-time backup to Supabase PostgreSQL database
- Cross-device access (manager can check from home)
- Conflict resolution for simultaneous edits
- Automatic sync when connectivity resumes
- JWT-based token authentication for secure cloud access

### Why Supabase Over Firebase?
| Factor | Firebase | Supabase |
|--------|----------|----------|
| Database | NoSQL (Firestore) | PostgreSQL (relational) |
| Pricing | Pay-per-read/write (unpredictable) | Generous free tier, predictable pricing |
| Open Source | No | Yes (self-hostable) |
| SQL Queries | Limited | Full SQL power |
| Auth | Firebase Auth | Built-in auth with JWT |
| Real-time | Firestore listeners | PostgreSQL real-time subscriptions |
| Offline support | Built-in | Requires client-side queue (already built via SQLite) |

### Sync Architecture (Planned)
```
Phone A (Store) ──┐
                  ├──► Supabase Cloud ──► Phone B (Manager at home)
Phone C (Staff) ──┘        │
                           ▼
                    Web Dashboard (future)
```

---

## 7. Application Screen Map

```
App Launch
│
├── Splash Screen
│   ├── First time? → Tutorial (4 pages) → Company Registration
│   └── Returning? → Login Screen
│
├── Login Screen (6-digit PIN)
│   └── Home Screen (4 tabs)
│       │
│       ├── Tab 1: Dashboard
│       │   ├── Statistics: Products, Value, Low Stock
│       │   ├── AI Insights Panel (Manager only)
│       │   │   ├── Demand Forecasts
│       │   │   ├── Sales Trends
│       │   │   └── Smart Recommendations
│       │   ├── Low Stock Alerts with "Order" buttons
│       │   └── Quick Actions: Add Product, Record Sale, Manage Users
│       │
│       ├── Tab 2: Inventory
│       │   ├── Search bar
│       │   ├── Product list with stock level indicators
│       │   ├── Tap → Edit product
│       │   └── Swipe → Delete (Manager only)
│       │
│       ├── Tab 3: Sales (Point of Sale)
│       │   ├── Product dropdown
│       │   ├── Quantity selector (+/-)
│       │   ├── Total amount display
│       │   ├── Notes field
│       │   ├── "Charge" button
│       │   └── Recent sales history
│       │
│       └── Tab 4: Reports
│           ├── Sales Report (today/week/month, top products, trends)
│           ├── Inventory Report (stats, categories, values)
│           ├── Employee Performance (Manager only)
│           ├── Profit Analysis (Manager only)
│           └── PDF Export button
│
├── User Management Screen (Manager only)
│   ├── Staff list
│   ├── Create new staff
│   ├── Deactivate / Reactivate
│   └── Reset PIN
│
└── AI Detailed Forecast Screen
    ├── Per-product forecast cards
    ├── Current stock vs predicted demand
    ├── Risk classification (HIGH / HEALTHY)
    └── Recommended order quantities
```

---

## 8. Security Model

| Layer              | Implementation |
|--------------------|----------------|
| Authentication     | 6-character PIN (alphanumeric) |
| Authorization      | Role-based (Manager/Staff) |
| Data Isolation     | companyId filter on all queries |
| Session            | User object passed through navigation |
| Audit Trail        | Every action logged with userId, timestamp, details |
| Offline Security   | Data in SQLite on device (encrypted storage recommended) |

---

## 9. Technology Stack

| Component          | Technology |
|--------------------|------------|
| Frontend           | Flutter (Dart) |
| Local Database     | SQLite via sqflite |
| Cloud Database     | Supabase (PostgreSQL) — replacing Firebase |
| AI/ML              | ml_algo + ml_dataframe (on-device linear regression) |
| PDF Reports        | pdf + printing packages |
| Notifications      | flutter_local_notifications |
| State Management   | StatefulWidget (built-in) |
| Fonts              | Google Fonts (Poppins) |
| Target Platform    | Android (primary), iOS (secondary) |

---

## 10. Customer Order Monitoring (Objective 3)

This objective ("To monitor customer orders") is addressed through Aura's **sales recording and audit system**:

### Current Implementation
- **Sales Screen**: Every customer purchase is recorded with product, quantity, price, date, and optional notes
- **Sales Reports**: Manager can view daily/weekly/monthly sales breakdowns, top products, and revenue trends
- **Audit Logs**: Every sale is tracked with the employee who processed it, creating a complete order history
- **AI Analysis**: Sales patterns are analyzed to identify peak days, slow periods, and demand trends

### How It Maps to "Monitoring Customer Orders"
1. **Order Recording**: Each sale = a customer order. The Sales screen acts as a simple POS (point of sale)
2. **Order History**: The Reports tab shows all past orders with filtering by date range
3. **Order Analytics**: AI insights reveal which products customers order most, peak buying times, and seasonal trends
4. **Employee Accountability**: Audit logs show which staff member processed each order
5. **Real-time Tracking**: Dashboard updates in real-time as sales are recorded throughout the day

### For the Document
> *"Customer order monitoring is implemented through a comprehensive point-of-sale system integrated into the mobile application. Each transaction is recorded with full details including product, quantity, unit price, total amount, timestamp, and the employee who processed it. The system provides real-time sales dashboards, historical order analytics with daily/weekly/monthly views, and AI-powered pattern recognition that identifies peak ordering days and demand trends. An audit trail ensures complete accountability for every transaction processed through the system."*

---

## 11. Competitive Advantages

1. **Affordable**: Free to deploy, runs on any Android phone
2. **Offline-First**: Works without internet — critical for areas with unstable connectivity
3. **AI-Powered**: Demand forecasting usually reserved for enterprise software
4. **Simple**: 6-digit PIN login, minimal training required
5. **Multi-Tenant**: One app serves unlimited businesses
6. **Accountable**: Full audit trail of every action
7. **Exportable**: PDF reports for external bookkeeping
