<style>
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap');

body, p, li, td, th, blockquote {
  font-family: 'Poppins', 'Segoe UI', sans-serif;
  font-size: 13px;
  line-height: 1.7;
  color: #1a1a2e;
}

h1 {
  font-family: 'Poppins', sans-serif;
  font-size: 28px;
  font-weight: 700;
  color: #0d0d0d;
  border-bottom: 3px solid #0d0d0d;
  padding-bottom: 10px;
  margin-bottom: 6px;
}

h2 {
  font-family: 'Poppins', sans-serif;
  font-size: 18px;
  font-weight: 600;
  color: #1a1a2e;
  border-bottom: 1.5px solid #e0e0e0;
  padding-bottom: 6px;
  margin-top: 36px;
}

h3 {
  font-family: 'Poppins', sans-serif;
  font-size: 14px;
  font-weight: 600;
  color: #333;
  margin-top: 24px;
  margin-bottom: 4px;
}

h4 {
  font-family: 'Poppins', sans-serif;
  font-size: 13px;
  font-weight: 500;
  color: #555;
}

code, pre {
  font-family: 'Courier New', monospace;
  background: #f4f4f4;
  border-radius: 4px;
  padding: 2px 6px;
  font-size: 12px;
}

table {
  border-collapse: collapse;
  width: 100%;
  margin: 16px 0;
  font-size: 12.5px;
}

th {
  background-color: #1a1a2e;
  color: #ffffff;
  padding: 10px 14px;
  font-weight: 600;
  text-align: left;
}

td {
  padding: 8px 14px;
  border-bottom: 1px solid #e8e8e8;
}

tr:nth-child(even) td {
  background-color: #fafafa;
}

blockquote {
  border-left: 4px solid #1a1a2e;
  margin: 16px 0;
  padding: 10px 16px;
  background: #f8f8ff;
  color: #333;
  border-radius: 0 8px 8px 0;
}

strong {
  font-weight: 600;
  color: #0d0d0d;
}

hr {
  border: none;
  border-top: 1px solid #e0e0e0;
  margin: 28px 0;
}
</style>

# Aura — Client Acceptance Test Guide
### Version 1.0.0+10 &nbsp;|&nbsp; Revised: April 27, 2026

---

> **Purpose:** This document is your complete, step-by-step guide to testing every feature of **Aura** — the AI-Powered Beverage Inventory Management System. Follow each section in order to verify that the application works correctly. All recent updates and improvements are reflected here.

---

## Before You Begin

### How to Install the App (Clean Install)

To guarantee a fresh experience with no leftover data from previous versions, follow these steps exactly:

1. On your Android device, go to **Settings → Apps → Aura**
2. Tap **Uninstall** — this removes all local data and the old notification channel cache
3. Transfer `Aura.apk` to your phone (via USB cable, WhatsApp, or email)
4. Open the file and tap **Install**
5. If the phone shows *"Install from unknown sources"*, tap **Allow** — this is required for sideloaded apps
6. Launch **Aura** from your home screen

> **Important:** Always uninstall before installing a new version. This ensures notification channels and app settings are created fresh.

---

### Files You Will Need

| File | Where to Find It | What It Is For |
|------|-----------------|----------------|
| `Aura.apk` | Project root folder | The application to install |
| `test_sales_import.xlsx` | Project root folder | Excel file used for import testing |

---

### Internet Requirement

Tests marked with **☁️** require an active internet connection (Wi-Fi or mobile data). All other tests run completely offline with no internet needed.

---

## Section 1 — First Launch & Onboarding

*This section covers what a brand-new user sees when opening Aura for the very first time on a freshly installed device.*

---

### TEST 1.1 — Splash Screen

**Steps:**
1. Tap the **Aura** icon on your home screen

**What to expect:**
- The Aura logo and app name animate smoothly onto the screen
- After 2–3 seconds the app transitions forward automatically
- A system permission dialog appears: *"Allow Aura to send you notifications?"* — tap **Allow**

> **Why this matters:** Granting notification permission is required for the cloud sync alerts to appear on your screen. If you tap Deny, you can re-enable notifications later in Settings → Apps → Aura → Notifications.

---

### TEST 1.2 — Onboarding Tutorial

**Steps:**
1. After the splash screen, the tutorial carousel appears
2. Swipe through each of the 4 slides
3. On the final slide, tap **Get Started**

**What to expect:**
- 4 illustrated slides explain the key features of the app
- Each slide responds to swipe gestures
- Tapping **Get Started** on the last slide takes you to the Manager Authentication screen
- The tutorial is shown only once — it will not appear again after this

---

## Section 2 — Company Setup

*Every store using Aura must be registered before anyone can log in. This is a one-time setup performed by the Manager.*

---

### TEST 2.1 — Register a New Company

**Steps:**
1. On the Manager Authentication screen, tap **Register New Company**
2. Enter a company name, e.g. `Siyaz Beverages`
3. Enter the manager's full name, e.g. `Kelly Nxumalo`
4. Tap **Register**

**What to expect:**
- A confirmation dialog appears showing:
  - Your company name
  - An auto-generated **Company ID** (e.g. `company_siy_1714956000000`) — used to link additional devices to this company
  - Your **Manager PIN** (e.g. `SIY447`) — 3 letters from the company name + 3 random digits

> **Write down your Manager PIN and Company ID now.** These cannot be recovered if lost. The PIN is used to log in as Manager on this and any future devices.

- Tapping **Continue** navigates to the Login screen

---

### TEST 2.2 ☁️ — Join an Existing Company (Multi-Device Sync)

*This test demonstrates how a second device can join an existing company and pull all its data from the cloud.*

**Steps:**
1. On the Manager Authentication screen, tap **Join Existing Company**
2. Enter the Company ID: `company_test_beverages_ltd_4888`
3. Tap **Join**

**What to expect:**
- Progress messages appear and update in sequence:
  - *"Verifying company..."*
  - *"Fetching team members..."*
  - *"Syncing products..."*
  - *"Syncing recent sales..."*
  - *"Syncing audit logs..."*
  - *"Saving locally..."*
- A green confirmation banner appears: *"Synced: X users, X products, X sales"* — the numbers shown are the actual counts pulled from the cloud
- The app moves to the Login screen with all data ready
- **The app must not freeze, crash, or show a blank screen at any point**

> **What changed in this version:** Joining a company now correctly retrieves all team member accounts from the cloud. Previously, the sync reported 0 users. This has been fixed — staff members registered under the company will now appear on the device after joining.

---

**Sub-test — Invalid Company ID:**
1. Tap **Join Existing Company**
2. Enter: `company_does_not_exist_9999`
3. Tap **Join**

**What to expect:**
- Clear error: *"No company found with ID: company_does_not_exist_9999"*
- The button is re-enabled so you can correct and retry

---

**Sub-test — No Internet:**
1. Enable Airplane Mode on your device
2. Try to join any company

**What to expect:**
- After 15 seconds, a descriptive error: *"Connection timed out. Check your internet and try again."*
- The app does not freeze or crash

---

## Section 3 — Authentication

---

### TEST 3.1 — Manager Login

**Steps:**
1. On the Login screen, enter the Manager PIN that was shown during registration
2. Tap **Login**

**What to expect:**
- Successful login; the Dashboard opens
- A **MANAGER** badge is visible near the top of the screen
- All features are accessible: Reports, User Management, AI Insights, Stock Adjustment

---

### TEST 3.2 — Staff Login

**Steps:**
1. First load demo data (see Section 4.1) — this creates staff accounts with auto-generated PINs
2. Log out (tap your name or the logout option)
3. On the Login screen, enter a staff member's PIN

**What to expect:**
- Successful login with a **STAFF** badge displayed
- Restricted access is enforced: Employee Performance and Profit Analysis are hidden in Reports; User Management is not accessible

---

### TEST 3.3 — Wrong PIN

**Steps:**
1. Enter an incorrect PIN (e.g. `000000`)
2. Tap **Login**

**What to expect:**
- Error message: *"Incorrect PIN"*
- The field clears; you can try again
- No crash

---

## Section 4 — Dashboard

*The Dashboard is the main home screen after login. It provides a live overview of your store's performance at a glance.*

---

### TEST 4.1 — Load Demo Data

*This fills the app with realistic sample data so that all other sections of this test plan have something to work with.*

**Steps:**
1. Log in as Manager
2. Tap the **⋮** (three-dot) menu in the top-right corner of the Dashboard
3. Tap **Load Demo Data**
4. Confirm when prompted

**What to expect:**
- 10 beverage products are created (Coca-Cola, Pepsi, Fanta, Sprite, Mazoe Orange, Ceres Apple Juice, Schweppes Tonic, Minute Maid, Aquafresh Water, Mountain Dew)
- 5 staff accounts are created with auto-generated PINs
- Approximately 24 historical sales records are generated across the past 30 days
- Dashboard statistics update immediately to reflect the new data

---

### TEST 4.2 — Dashboard Stats Cards

**Steps:**
1. After loading demo data, observe the four summary cards on the Dashboard

**What to expect:**
- **Products** card shows **10**
- **Sales Today** may show 0 — the demo data uses historical dates, not today
- **Low Stock** shows the count of products below their minimum quantity (Fanta, Sprite, and Mountain Dew are intentionally set low)
- **Pending Orders** shows **0** (no orders have been created yet)

---

### TEST 4.3 — Dashboard Quick Action Buttons

**Steps:**
1. On the Dashboard, locate the row of action buttons
2. Tap each one and verify it opens the correct screen

| Button | Expected Screen |
|--------|----------------|
| **Orders** | Orders list screen |
| **Stock Adjustment** | Stock Adjustment screen |
| **User Management** *(Manager only)* | User Management screen |
| **AI Insights** *(Manager only)* | AI Detailed Forecast screen |

---

### TEST 4.4 — Import Sales via Excel Menu

**Steps:**
1. Tap the **⋮** menu on the Dashboard
2. Tap **Import Sales (Excel)**

**What to expect:**
- The Excel Import screen opens (covered fully in Section 9)

---

### TEST 4.5 — Clear All Data

**Steps:**
1. Tap the **⋮** menu on the Dashboard
2. Tap **Clear All Data**
3. Confirm the warning dialog

**What to expect:**
- All products, sales, users (except the current manager), orders, and audit logs are deleted
- Dashboard resets to an empty state
- The app does not crash

> **Note:** After running this test, reload demo data (Test 4.1) before continuing with remaining sections.

---

## Section 5 — Inventory Management

---

### TEST 5.1 — Product List

**Steps:**
1. Tap the **Inventory** tab (box icon at the bottom of the screen)

**What to expect:**
- All 10 demo products are listed
- Each card shows the product name, category, current stock quantity, and selling price
- Stock levels are colour-coded: **green** (healthy), **amber** (low), **red** (critical or out of stock)
- Fanta Orange, Sprite, and Mountain Dew should appear as low or critical

---

### TEST 5.2 — Search Products

**Steps:**
1. Tap the search bar on the Inventory screen
2. Type `coca`

**What to expect:**
- The list filters instantly to show only *Coca-Cola 500ml*
- Clearing the search bar restores the full product list

---

### TEST 5.3 — Add a New Product

**Steps:**
1. Tap the **+** button on the Inventory screen
2. Fill in the following:
   - Name: `Red Bull 250ml`
   - Category: `Energy Drink`
   - Quantity: `24`
   - Min Quantity: `10`
   - Cost Price: `1.20`
   - Selling Price: `2.50`
   - Supplier: `Red Bull GmbH`
3. Tap **Save**

**What to expect:**
- The product appears in the inventory list with a green stock indicator (24 is above the minimum of 10)

---

### TEST 5.4 — Edit a Product

**Steps:**
1. Tap on *Aquafresh Water 500ml* in the list
2. Change the Selling Price to `1.00`
3. Tap **Save**

**What to expect:**
- The product updates immediately; the new price is reflected in the list

---

### TEST 5.5 — Delete a Product *(Manager only)*

**Steps:**
1. Tap on *Red Bull 250ml* (added in Test 5.3)
2. Tap **Delete**
3. Confirm the dialog

**What to expect:**
- Product is removed from the list
- A brief confirmation message appears

---

### TEST 5.6 — Pull to Refresh

**Steps:**
1. On the Inventory screen, swipe down from the top of the list

**What to expect:**
- A loading indicator briefly appears
- The product list reloads from the local database

---

## Section 6 — Sales (Point of Sale)

---

### TEST 6.1 — Record a Sale

**Steps:**
1. Tap the **Sales** tab (cart icon at the bottom)
2. Tap the product dropdown and select *Coca-Cola 500ml*
   - The dropdown shows the current available stock next to each product name, e.g. `Coca-Cola 500ml (47 left)`
3. Tap the **Qty** field and type `3`

> **New in this version:** The quantity field is now blank by default with a `Qty` placeholder. Simply tap the field and type your number — there is no pre-filled value to clear or edit first.

4. Tap **Add**
5. Tap **Charge**

**What to expect:**
- The sale is recorded
- Coca-Cola stock decreases by 3
- The sale appears in the Recent Sales list
- Total amount is correct: 3 × $1.50 = **$4.50**

---

### TEST 6.2 ☁️ — Cloud Sync Notification

**Steps:**
1. Immediately after completing Test 6.1

**What to expect:**
- Within approximately 1 second, a **push notification** appears in the Android notification bar:
  - Title: **☁️ Synced to Cloud**
  - Body: *"1 record saved to the cloud"*
- Pull down the notification shade to see it

> **About this notification:** The app sends cloud sync alerts using Android's native notification system. This is why notifications appear instantly as a banner, even if the app is open in the foreground.

---

### TEST 6.3 ☁️ — Batched Sync Notification

**Steps:**
1. Make 3 sales in quick succession (within 2–3 seconds of each other)

**What to expect:**
- A single batched notification appears rather than one per sale:
  - Body: *"3 records saved to the cloud"*

---

### TEST 6.4 — Overselling Prevention

**Steps:**
1. Select any product with a low stock count (e.g. *Fanta Orange 500ml*)
2. In the **Qty** field, type a number higher than the available stock (e.g. if 5 remain, type `10`)
3. Tap **Add**

**What to expect:**
- A red error message: *"Not enough stock! Available: 5"*
- Nothing is added to the cart
- The sale cannot proceed with more units than are physically in stock

---

### TEST 6.5 — Stock Decreases After Sale

**Steps:**
1. Note the current stock quantity of *Pepsi 500ml* in Inventory
2. Go to the Sales screen and sell 5 units of *Pepsi 500ml*
3. Return to Inventory and check *Pepsi 500ml* again

**What to expect:**
- The Pepsi stock count has decreased by exactly 5

---

## Section 7 — Orders Management

*The Orders module allows your business to capture customer orders, track their fulfilment status, and manage delivery.*

---

### TEST 7.1 — Create a New Order

**Steps:**
1. From the Dashboard, tap **Orders**
2. Tap the **+** button to create a new order
3. Fill in the customer details:
   - Customer Name: `John Moyo`
   - Customer Phone: `0771234567`
4. Add items to the order:
   - Select *Coca-Cola 500ml* from the product dropdown
     - The dropdown shows available stock: e.g. `Coca-Cola 500ml (47 left)`
   - Tap the **Qty** field and type `12`
   - Tap the **+** (add) button
   - Select *Aquafresh Water 500ml* and add `24`
5. Optionally, add a note in the **Notes** field (e.g. `Deliver before 10am`)
6. Tap **Place Order**

> **New in this version:** The order form is now stock-aware. The product dropdown shows the number of units currently available. If you attempt to add a quantity greater than what is in stock, the app will show a red error and block the addition. This prevents orders that cannot be fulfilled.
>
> The quantity field uses a placeholder (`Qty`) — simply tap and type your number directly.

**What to expect:**
- The order is created and appears in the **Pending** tab of the Orders list
- The order card shows customer name, number of items, and total amount

---

### TEST 7.2 — Stock Over-Order Prevention

**Steps:**
1. While creating a new order, select any product
2. In the Qty field, type a number larger than the available stock
3. Tap the **+** (add) button

**What to expect:**
- Red error message: *"Only X in stock for [Product Name]"*
- The item is not added to the order

---

### TEST 7.3 — View Order Detail

**Steps:**
1. From the Orders screen, tap the order created in Test 7.1

**What to expect:**
- Order detail screen opens showing:
  - Customer name and phone number
  - List of items with quantities and unit prices
  - Order total amount
  - Current status: **Pending**
  - Notes (if any were entered)

---

### TEST 7.4 — Update Order Status

**Steps:**
1. Inside the order detail, change the status to **Processing**
2. Save / confirm
3. Go back to the Orders list

**What to expect:**
- The order moves from the **Pending** tab to the **Processing** tab
- The status badge on the order card updates accordingly

---

### TEST 7.5 — Complete an Order

**Steps:**
1. Open the same order again
2. Change status to **Completed**

**What to expect:**
- The order appears in the **Completed** tab
- The **Pending Orders** count on the Dashboard decreases

---

### TEST 7.6 — Search Orders

**Steps:**
1. On the Orders screen, use the search bar
2. Type `John`

**What to expect:**
- Only orders with customer name matching *John Moyo* are shown

---

## Section 8 — Stock Adjustment

---

### TEST 8.1 — Adjust Stock Up

**Steps:**
1. From the Dashboard, tap **Stock Adjustment**
2. Select *Fanta Orange 500ml* (a low-stock product)
3. Enter adjustment: `+20`
4. Reason: `Stock delivery received`
5. Confirm

**What to expect:**
- Fanta stock increases by 20
- The change is recorded in the audit trail with the reason provided
- The Inventory screen reflects the updated quantity

---

### TEST 8.2 — Adjust Stock Down

**Steps:**
1. Open Stock Adjustment again
2. Select *Mazoe Orange 2L*
3. Enter adjustment: `-3`
4. Reason: `Damaged goods removed`
5. Confirm

**What to expect:**
- Mazoe Orange stock decreases by 3
- The audit log records the adjustment with the correct reason

---

## Section 9 — Excel Sales Import

*Before running these tests, make sure demo data is loaded (Test 4.1) so that product names already exist in the app.*

*Transfer `test_sales_import.xlsx` from the project root folder to your phone before starting.*

---

### TEST 9.1 — Import Valid and Error Rows

**Steps:**
1. From the Dashboard, tap **⋮** → **Import Sales (Excel)**
2. Tap **Select File**
3. Navigate to and select `test_sales_import.xlsx`

**What to expect:**
- The app parses the file and displays a preview table with 16 rows
- **12 rows shown in green** (valid records ready to import)
- **4 rows shown in red** (errors):
  - Row 13: *"Product 'Ginger Beer 330ml' not found in app"*
  - Row 14: *"Invalid date '99/99/2026'"*
  - Row 15: *"Invalid quantity '0'"*
  - Row 16: *"Missing product name"*
- Summary at the bottom: **12 valid, 4 errors**

---

### TEST 9.2 — Confirm Import

**Steps:**
1. After the preview in Test 9.1, tap **Import**

**What to expect:**
- Success message: *"12 sales imported successfully"*
- The 4 error rows are skipped without interrupting the import
- Sales history shows the newly imported records
- Inventory quantities decrease to reflect the imported sales

---

### TEST 9.3 — Import Invalid File

**Steps:**
1. Open Excel Import
2. Try selecting a non-Excel file (e.g. a PDF or image)

**What to expect:**
- The file picker restricts selection to `.xlsx` / `.xls` files only
- If an unsupported file is somehow selected, a clear error appears: *"Failed to read file"*

---

## Section 10 — Reports & PDF Export

---

### TEST 10.1 — Sales Report

**Steps:**
1. Tap the **Reports** tab (chart icon at the bottom)
2. Ensure you are on the **Sales** sub-tab

**What to expect:**
- Total revenue displayed for Today, This Week, and This Month
- Top products chart lists best-selling items by revenue
- Daily sales trend shows a bar chart for the past 7 days

---

### TEST 10.2 — Inventory Report

**Steps:**
1. On the Reports screen, tap **Inventory**

**What to expect:**
- Total stock value displayed (all products at selling price)
- Category breakdown (number of products and units per category)
- Low-stock items listed with their current and minimum quantities

---

### TEST 10.3 — Employee Performance *(Manager only)*

**Steps:**
1. On the Reports screen, tap **Employee Performance**

**What to expect:**
- Each staff member listed with total sales count and total revenue generated
- Data corresponds to the demo sales assigned to each staff member
- **Staff users do not see this tab**

---

### TEST 10.4 — Profit Analysis *(Manager only)*

**Steps:**
1. On the Reports screen, tap **Profit Analysis**

**What to expect:**
- Total revenue, cost of goods sold, gross profit, and profit margin percentage
- Products ranked by profit margin
- **Staff users do not see this tab**

---

### TEST 10.5 — Export PDF Report

**Steps:**
1. On any Reports sub-tab, tap **Export PDF**
2. Wait for the report to generate

**What to expect:**
- The Android Share Sheet appears (save to device, WhatsApp, email, etc.)
- Opening the PDF shows a professionally formatted report with:
  - Aura branding header
  - Data tables and charts
  - Company name and export date

---

## Section 11 — Notifications Screen

---

### TEST 11.1 — View In-App Notifications

**Steps:**
1. Tap the **Notifications** tab (bell icon at the bottom)

**What to expect:**
- Stock alert notifications appear for any products below their minimum quantity
- A badge on the bell icon shows the number of unread alerts

---

### TEST 11.2 — Badge Count Updates

**Steps:**
1. Note the current badge count on the bell icon
2. Perform a Stock Adjustment that brings a low-stock item above its minimum (Test 8.1)
3. Return to the Notifications tab

**What to expect:**
- The badge count decreases as resolved alerts are dismissed

---

## Section 12 — AI Features

*These tests require demo data to be loaded (Test 4.1). The AI engine needs at least 7 days of historical sales data to generate forecasts.*

---

### TEST 12.1 — AI Insights Card on Dashboard

**Steps:**
1. Go to the Dashboard
2. Find the **AI Insights** card

**What to expect:**
- At least one AI-generated insight is displayed, for example:
  - *"Coca-Cola 500ml will run out in approximately 4 days at current rate"*
  - *"Friday is your peak sales day (+35% above average)"*
  - *"Sprite 500ml has a high stockout risk — recommend reordering 21 units"*

---

### TEST 12.2 — Detailed AI Forecast Screen

**Steps:**
1. From the Dashboard, tap **AI Insights** (or the arrow on the AI card)

**What to expect:**
- A full forecast screen lists every product with:
  - Predicted sales for the next 7 days
  - Current stock vs. predicted demand
  - Recommended reorder quantity
  - Risk level: **HIGH** (will run out) shown in red, or **HEALTHY** (sufficient stock) in green
- Tapping any product opens an individual detailed forecast view

---

### TEST 12.3 — Sales Pattern Recognition

**Steps:**
1. On the AI Forecast screen, scroll to the Sales Patterns section

**What to expect:**
- Peak sales day identified with percentage above average (e.g. *"Friday is your strongest day"*)
- Slowest sales day identified (e.g. *"Monday has the lowest volume"*)

---

## Section 13 — User Management *(Manager only)*

---

### TEST 13.1 — View Staff List

**Steps:**
1. From the Dashboard, tap **User Management**

**What to expect:**
- All demo staff members are listed with their name, role, and active/inactive status

---

### TEST 13.2 — Create a New Staff Member

**Steps:**
1. Tap the **+** button
2. Enter:
   - Full Name: `Tafadzwa Moyo`
   - Role: `Staff`
   - Phone: `0779876543`
3. Tap **Create**

**What to expect:**
- A PIN is auto-generated and displayed (e.g. `TAF821`)
- The new staff member appears in the list
- They can immediately log in using their new PIN

---

### TEST 13.3 — Deactivate a Staff Member

**Steps:**
1. Tap on any staff member in the list
2. Toggle their status to **Inactive**

**What to expect:**
- Their status label changes to Inactive
- If they attempt to log in, they receive: *"Account deactivated"*

---

### TEST 13.4 — Reactivate a Staff Member

**Steps:**
1. Tap on the same staff member
2. Toggle their status back to **Active**

**What to expect:**
- Their account is restored and their PIN works again

---

### TEST 13.5 — Reset Staff PIN

**Steps:**
1. Tap on a staff member
2. Tap **Reset PIN**

**What to expect:**
- A newly generated PIN is displayed
- The previous PIN no longer works
- The new PIN grants login access

---

## Test Results Summary

Use this table to record outcomes as you work through each section:

| # | Test | Result | Notes |
|---|------|--------|-------|
| 1.1 | Splash Screen | ☐ Pass &nbsp; ☐ Fail | |
| 1.2 | Onboarding Tutorial | ☐ Pass &nbsp; ☐ Fail | |
| 2.1 | Register New Company | ☐ Pass &nbsp; ☐ Fail | |
| 2.2 | Join Existing Company | ☐ Pass &nbsp; ☐ Fail | |
| 3.1 | Manager Login | ☐ Pass &nbsp; ☐ Fail | |
| 3.2 | Staff Login | ☐ Pass &nbsp; ☐ Fail | |
| 3.3 | Wrong PIN | ☐ Pass &nbsp; ☐ Fail | |
| 4.1 | Load Demo Data | ☐ Pass &nbsp; ☐ Fail | |
| 4.2 | Dashboard Stats Cards | ☐ Pass &nbsp; ☐ Fail | |
| 4.3 | Quick Action Buttons | ☐ Pass &nbsp; ☐ Fail | |
| 4.4 | Excel Menu Item | ☐ Pass &nbsp; ☐ Fail | |
| 4.5 | Clear All Data | ☐ Pass &nbsp; ☐ Fail | |
| 5.1 | Product List | ☐ Pass &nbsp; ☐ Fail | |
| 5.2 | Search Products | ☐ Pass &nbsp; ☐ Fail | |
| 5.3 | Add Product | ☐ Pass &nbsp; ☐ Fail | |
| 5.4 | Edit Product | ☐ Pass &nbsp; ☐ Fail | |
| 5.5 | Delete Product | ☐ Pass &nbsp; ☐ Fail | |
| 5.6 | Pull to Refresh | ☐ Pass &nbsp; ☐ Fail | |
| 6.1 | Record a Sale | ☐ Pass &nbsp; ☐ Fail | |
| 6.2 | Cloud Sync Notification | ☐ Pass &nbsp; ☐ Fail | |
| 6.3 | Batched Sync Notification | ☐ Pass &nbsp; ☐ Fail | |
| 6.4 | Overselling Prevention | ☐ Pass &nbsp; ☐ Fail | |
| 6.5 | Stock Decreases After Sale | ☐ Pass &nbsp; ☐ Fail | |
| 7.1 | Create Order | ☐ Pass &nbsp; ☐ Fail | |
| 7.2 | Stock Over-Order Prevention | ☐ Pass &nbsp; ☐ Fail | |
| 7.3 | View Order Detail | ☐ Pass &nbsp; ☐ Fail | |
| 7.4 | Update Order Status | ☐ Pass &nbsp; ☐ Fail | |
| 7.5 | Complete Order | ☐ Pass &nbsp; ☐ Fail | |
| 7.6 | Search Orders | ☐ Pass &nbsp; ☐ Fail | |
| 8.1 | Stock Adjust Up | ☐ Pass &nbsp; ☐ Fail | |
| 8.2 | Stock Adjust Down | ☐ Pass &nbsp; ☐ Fail | |
| 9.1 | Excel Import Preview | ☐ Pass &nbsp; ☐ Fail | |
| 9.2 | Confirm Import | ☐ Pass &nbsp; ☐ Fail | |
| 9.3 | Invalid File | ☐ Pass &nbsp; ☐ Fail | |
| 10.1 | Sales Report | ☐ Pass &nbsp; ☐ Fail | |
| 10.2 | Inventory Report | ☐ Pass &nbsp; ☐ Fail | |
| 10.3 | Employee Performance | ☐ Pass &nbsp; ☐ Fail | |
| 10.4 | Profit Analysis | ☐ Pass &nbsp; ☐ Fail | |
| 10.5 | Export PDF | ☐ Pass &nbsp; ☐ Fail | |
| 11.1 | In-App Notifications | ☐ Pass &nbsp; ☐ Fail | |
| 11.2 | Badge Count Updates | ☐ Pass &nbsp; ☐ Fail | |
| 12.1 | AI Dashboard Card | ☐ Pass &nbsp; ☐ Fail | |
| 12.2 | AI Forecast Screen | ☐ Pass &nbsp; ☐ Fail | |
| 12.3 | Sales Pattern Recognition | ☐ Pass &nbsp; ☐ Fail | |
| 13.1 | View Staff List | ☐ Pass &nbsp; ☐ Fail | |
| 13.2 | Create Staff Member | ☐ Pass &nbsp; ☐ Fail | |
| 13.3 | Deactivate Staff | ☐ Pass &nbsp; ☐ Fail | |
| 13.4 | Reactivate Staff | ☐ Pass &nbsp; ☐ Fail | |
| 13.5 | Reset Staff PIN | ☐ Pass &nbsp; ☐ Fail | |

---

## Appendix A — Demo Product Reference

The 10 products created by Load Demo Data. Product names must match exactly when importing via Excel (case-insensitive).

| Product Name | Category | Selling Price | Min Stock |
|-------------|----------|:------------:|:---------:|
| Coca-Cola 500ml | Soft Drink | $1.50 | 20 |
| Pepsi 500ml | Soft Drink | $1.45 | 20 |
| Fanta Orange 500ml | Soft Drink | $1.40 | 15 |
| Sprite 500ml | Soft Drink | $1.40 | 15 |
| Mazoe Orange 2L | Juice Concentrate | $4.00 | 10 |
| Ceres Apple Juice 1L | Juice | $3.00 | 10 |
| Schweppes Tonic 500ml | Mixer | $1.60 | 10 |
| Minute Maid Orange 500ml | Juice | $2.00 | 15 |
| Aquafresh Water 500ml | Water | $0.80 | 50 |
| Mountain Dew 500ml | Soft Drink | $1.45 | 15 |

---

## Appendix B — What's New in This Version

The following improvements have been made since the previous test plan:

| Area | Change |
|------|--------|
| **Join Company** | Now correctly retrieves all staff accounts from the cloud (previously reported 0 users synced) |
| **Cloud Notifications** | Sync alerts now use Android's native notification engine — banners appear instantly and reliably, even in the foreground |
| **Sales — Quantity Field** | Field is blank by default with a `Qty` hint; type your number directly without clearing a pre-filled value |
| **Orders — Quantity Field** | Wider, cleaner field with the same blank-with-hint behaviour |
| **Orders — Stock Awareness** | Dropdown shows available stock per product; adding more units than available is blocked with a clear error message |

---

*Aura v1.0.0+10 — Revised April 27, 2026*
