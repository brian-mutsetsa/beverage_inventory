# Supabase Database Setup for Aura

## Quick Start

1. Go to [supabase.com](https://supabase.com) and create a free project
2. Open the **SQL Editor** in your Supabase dashboard
3. Paste and run the SQL below to create all tables
4. Go to **Settings → API** and copy your **Project URL** and **anon public key**
5. Paste them into `lib/services/supabase_config.dart`

## SQL Migration Script

Run this in the Supabase SQL Editor:

```sql
-- ============================================================
-- Aura Beverage Inventory — Supabase PostgreSQL Schema
-- ============================================================

-- Companies table
CREATE TABLE IF NOT EXISTS companies (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  company_id TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  created_by TEXT NOT NULL,
  created_at TEXT NOT NULL,
  synced_at TIMESTAMPTZ DEFAULT NOW()
);

-- Products table
CREATE TABLE IF NOT EXISTS products (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  local_id INTEGER NOT NULL,
  company_id TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  min_quantity INTEGER NOT NULL DEFAULT 0,
  cost_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  selling_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  supplier TEXT NOT NULL DEFAULT '',
  barcode TEXT,
  image_path TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, local_id)
);

-- Sales table
CREATE TABLE IF NOT EXISTS sales (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  local_id INTEGER NOT NULL,
  company_id TEXT NOT NULL,
  product_id INTEGER NOT NULL,
  product_name TEXT NOT NULL,
  quantity_sold INTEGER NOT NULL DEFAULT 0,
  unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  sale_date TEXT NOT NULL,
  notes TEXT,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, local_id)
);

-- Users table (named app_users to avoid PostgreSQL reserved word conflict)
CREATE TABLE IF NOT EXISTS app_users (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  local_id INTEGER NOT NULL,
  company_id TEXT NOT NULL,
  pin TEXT NOT NULL,
  full_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'staff',
  phone TEXT,
  is_active INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  created_by INTEGER,
  last_login TEXT,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, local_id)
);

-- Audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  local_id INTEGER NOT NULL,
  company_id TEXT NOT NULL,
  user_id INTEGER NOT NULL,
  user_name TEXT NOT NULL,
  action TEXT NOT NULL,
  details TEXT,
  timestamp TEXT NOT NULL,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(company_id, local_id)
);

-- ============================================================
-- Indexes for fast lookups
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_companies_company_id ON companies(company_id);
CREATE INDEX IF NOT EXISTS idx_products_company ON products(company_id);
CREATE INDEX IF NOT EXISTS idx_sales_company ON sales(company_id);
CREATE INDEX IF NOT EXISTS idx_app_users_company ON app_users(company_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_company ON audit_logs(company_id);
CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date);
CREATE INDEX IF NOT EXISTS idx_app_users_pin ON app_users(pin);

-- ============================================================
-- Row Level Security (RLS)
-- 
-- Since Aura uses PIN-based auth (not Supabase Auth), we use
-- a simple policy that allows all operations via the anon key.
-- For production, you would tie this to Supabase Auth and
-- enforce company_id-based isolation.
-- ============================================================

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Allow all operations for now (anon key access)
CREATE POLICY "Allow all for companies" ON companies FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for products" ON products FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for sales" ON sales FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for app_users" ON app_users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all for audit_logs" ON audit_logs FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- Enable Realtime 
-- Go to Database → Replication in Supabase dashboard and 
-- enable realtime for: products, sales, app_users, audit_logs
-- OR run these:
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE companies;
ALTER PUBLICATION supabase_realtime ADD TABLE products;
ALTER PUBLICATION supabase_realtime ADD TABLE sales;
ALTER PUBLICATION supabase_realtime ADD TABLE app_users;
ALTER PUBLICATION supabase_realtime ADD TABLE audit_logs;
```

## After Running the SQL

1. In the Supabase dashboard, go to **Database → Replication**
2. Confirm that `products`, `sales`, `app_users`, and `audit_logs` are listed under the realtime publication
3. Go to **Settings → API** and copy:
   - **Project URL** (looks like `https://xxxx.supabase.co`)
   - **anon public** key (a long JWT string)
4. Open `lib/services/supabase_config.dart` and replace the placeholder values

## Testing

After configuration:
1. Run the app on two devices/emulators with the same company PIN
2. Add a product on Device A
3. It should appear on Device B within seconds via real-time sync

## Architecture Notes

- **Offline-first**: SQLite remains the primary local database. The app works fully offline.
- **Push on write**: Every local create/update/delete is pushed to Supabase in the background.
- **Pull on login**: A full sync runs when a user logs in, pulling any cloud changes into local SQLite.
- **Real-time**: Supabase Realtime channels notify all connected devices when data changes. Screens auto-refresh.
- **Conflict resolution**: `UNIQUE(company_id, local_id)` with upsert ensures idempotent writes. Last-write-wins.

## Production Considerations

For a production deployment, you would want to:
- Replace the permissive RLS policies with company_id-based isolation tied to Supabase Auth
- Add `updated_at` timestamps for proper conflict resolution
- Implement incremental sync (only sync records newer than last sync timestamp)
- Add retry logic with exponential backoff for failed pushes
- Consider Supabase Edge Functions for server-side business logic
