# Phase 6: Advanced AI Features

**Status**: NOT STARTED
**Depends on**: Phase 1 (Bug Fixes), Phase 3 (Sales Upgrade — needs richer sales data)
**Complexity**: High
**New files**: 0-1 (possibly a new `supplier.dart` model) | **Modified files**: 3-5 | **New packages**: 0

---

## Goal
Expand the AI/ML layer beyond basic linear regression to provide seasonal trend detection, anomaly alerts, price optimization suggestions, and supplier performance tracking.

---

## Steps

### Step 6.1 — Seasonal Trend Detection
Detect repeating patterns in sales data tied to time of year, day of week, or month.

**Actions:**

1. **Add `getSeasonalTrends()` to `ai_service.dart`**:
   - Input: all sales for a given product (or overall), minimum 60 days of data
   - Group sales by month (or by day-of-week)
   - Calculate average sales per period
   - Return a map of period → average sales (e.g., `{ 'Mon': 45.0, 'Tue': 52.0, ... }`)
   - Guard: if < 60 days of data, return null with message "Need more data for seasonal analysis"
   - [ ] `getSeasonalTrends()` method implemented
   - [ ] Returns null gracefully when insufficient data

2. **Display seasonal insights in AI Insights Widget**:
   - Add a "Seasonal Trends" section
   - Show best day of week and best month (if enough data)
   - Example: "Tuesdays have 23% higher sales" or "December is your peak month"
   - Use a small bar chart (from `fl_chart`, added in Phase 5) showing day-of-week averages
   - [ ] Seasonal trends section added to widget
   - [ ] Bar chart renders correctly
   - [ ] Insights text is clear and accurate

---

### Step 6.2 — Anomaly Detection
Flag unusual sales patterns (sudden spikes or drops) that might indicate problems or opportunities.

**Actions:**

1. **Add `detectAnomalies()` to `ai_service.dart`**:
   - Input: daily sales totals for last 30 days
   - Calculate rolling 7-day mean and standard deviation
   - Any day with sales > mean + 2σ → "spike" anomaly
   - Any day with sales < mean − 2σ → "dip" anomaly
   - Return list of `{ date, type: 'spike'|'dip', value, expected }` objects
   - Guard: if < 14 days of data, return empty list
   - [ ] `detectAnomalies()` method implemented
   - [ ] Correctly identifies spikes and dips
   - [ ] Returns empty gracefully with insufficient data

2. **Display anomaly alerts**:
   - In AI Insights Widget, add "Recent Anomalies" section
   - Show each anomaly with date, type (spike/dip), actual vs expected
   - Color-code: green for spikes (good), red/orange for dips (investigate)
   - If no anomalies: "No unusual patterns detected" message
   - [ ] Anomaly alerts section added to widget
   - [ ] Spike/dip correctly color-coded
   - [ ] Empty state handled

3. **Optional: notification integration**:
   - When `detectAnomalies()` finds a new anomaly, trigger a local notification
   - Use existing `notification_service.dart` infrastructure
   - [ ] Anomaly notification fires (or deferred to later)

---

### Step 6.3 — Price Optimization Suggestions
Estimate price elasticity from historical data and suggest optimal pricing.

**Actions:**

1. **Add `getPriceOptimization()` to `ai_service.dart`**:
   - Input: sales history for a product at different price points (requires price changes over time)
   - If product has been sold at 2+ different prices, calculate simple elasticity:
     - `elasticity = (% change in quantity) / (% change in price)`
   - Suggest: if |elasticity| < 1 (inelastic), price increase may improve revenue
   - Suggest: if |elasticity| > 1 (elastic), price decrease may improve revenue
   - Return: `{ currentPrice, suggestedDirection: 'increase'|'decrease'|'hold', confidence: 'low'|'medium'|'high', reason }
   - Guard: if only 1 price point ever, return `{ suggestedDirection: 'hold', confidence: 'low', reason: 'Not enough price variation to analyze' }`
   - [ ] `getPriceOptimization()` implemented
   - [ ] Handles single-price-point gracefully
   - [ ] Multi-price-point calculation is accurate

2. **Display price suggestions**:
   - In AI Insights Widget or on individual product detail screen
   - Show suggestion with confidence level
   - Never show as a command ("Change price to $X") — always as a suggestion ("Consider increasing price — demand appears inelastic")
   - [ ] Price suggestions display in UI
   - [ ] Language is advisory, not prescriptive

---

### Step 6.4 — Supplier Performance Tracking
Track which suppliers deliver reliably and which are problematic.

**Actions:**

1. **Add `supplier` field to Product model**:
   - New optional field: `supplier` (String, nullable)
   - Update database schema (migration v4 → v5 or handle in existing migration)
   - Update `fromMap()` / `toMap()` for product
   - Add supplier text field to product add/edit screen
   - [ ] `supplier` field added to Product model
   - [ ] Database migration handles new column
   - [ ] Add/edit product screen includes supplier field

2. **Supplier reliability calculations in `ai_service.dart`**:
   - `getSupplierPerformance()`:
     - Group products by supplier
     - For each supplier: count products, average stock level, count of low-stock events
     - Reliability score = products that rarely go low-stock / total products (0.0 – 1.0)
   - Return: list of `{ supplier, productCount, avgStock, lowStockEvents, reliabilityScore }`
   - [ ] `getSupplierPerformance()` implemented
   - [ ] Reliability score calculation is logical

3. **Supplier performance display**:
   - New section in AI Insights or accessible from Reports screen
   - Table or list: Supplier name | # Products | Reliability Score | Status emoji (✅ > 0.8, ⚠️ 0.5-0.8, ❌ < 0.5)
   - Tap supplier → list of products from that supplier
   - [ ] Supplier performance section visible
   - [ ] Scores render correctly
   - [ ] Tap-through to product list works

---

### Step 6.5 — Testing

**Seasonal Trends:**
- [ ] With 60+ days of demo data → trends display correctly
- [ ] With < 60 days → "Need more data" message (no crash)
- [ ] Day-of-week averages are mathematically correct (spot-check)
- [ ] Bar chart matches the data

**Anomaly Detection:**
- [ ] Insert test data with an obvious spike → detected as anomaly
- [ ] Insert test data with an obvious dip → detected as anomaly
- [ ] Normal data → "No unusual patterns" message
- [ ] With < 14 days of data → empty list (no crash)

**Price Optimization:**
- [ ] Product with 2+ price points → suggestion rendered
- [ ] Product with only 1 price point → "Not enough data" message
- [ ] Suggestion language is advisory and clear

**Supplier Performance:**
- [ ] Add supplier names to several products
- [ ] Supplier table shows in AI Insights / Reports
- [ ] Reliability scores are reasonable
- [ ] Tap supplier → product list is filtered correctly
- [ ] Products without supplier → handled gracefully (group as "Unknown" or omit)

---

## Definition of Done
AI insights are richer with seasonal trends, anomaly alerts, and price suggestions. Supplier tracking provides a basic reliability view.

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
- [ ] Ready to proceed to Phase 7
