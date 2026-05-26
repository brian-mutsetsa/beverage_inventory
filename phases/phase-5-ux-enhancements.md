# Phase 5: UX Enhancements

**Status**: NOT STARTED
**Depends on**: Phase 1 (Bug Fixes & Verification)
**Complexity**: Low-Medium
**New files**: 0-1 | **Modified files**: 4-5 | **New packages**: 1 (`fl_chart`)

---

## Goal
Add quality-of-life features that make the app feel polished and professional: dashboard charts, dark mode, and animated screen transitions.

---

## Steps

### Step 5.1 — Dashboard Charts
The dashboard currently shows stats as cards with numbers. Adding visual charts makes trends immediately readable.

**Actions:**

1. **Add package** — Add `fl_chart` to `pubspec.yaml` and run `flutter pub get`
   - [ ] Package added and resolved

2. **Mini sales trend line chart** (last 7 days):
   - Use data from `getDailySales(days: 7)` (already exists in database_helper)
   - Render as a small line chart on the dashboard
   - X-axis: days (Mon–Sun or dates)
   - Y-axis: total sales amount
   - Style: use app's amber/gold color for the line
   - Tappable → navigates to Reports tab (Sales)
   - Manager only
   - [ ] Sales trend chart renders on dashboard
   - [ ] Data is accurate (matches Reports tab)
   - [ ] Tapping navigates to Reports

3. **Category breakdown donut/pie chart**:
   - Use data from `getProductsByCategory()` (already exists)
   - Render as a small donut chart showing product distribution by category
   - Each slice = one category, labeled
   - Tappable → navigates to Reports tab (Inventory)
   - Manager only
   - [ ] Category chart renders on dashboard
   - [ ] Slices match actual category distribution
   - [ ] Tapping navigates to Reports

4. **Layout integration**:
   - Place charts in a new section on the dashboard between stats cards and low-stock alerts
   - Side by side on larger screens, stacked on small screens
   - Add section header: "Quick Analytics" or similar
   - [ ] Charts section integrated into dashboard layout
   - [ ] Responsive layout works on different screen sizes

---

### Step 5.2 — Dark Mode
Allow users to switch between light and dark themes.

**Actions:**

1. **Define dark theme** in `main.dart`:
   - Background: dark grey (#1A1A1A or similar)
   - Surface: slightly lighter grey (#2A2A2A)
   - Primary: keep amber/gold accent (works well on dark)
   - Text: white/light grey
   - Cards: dark surface with subtle borders
   - Keep Poppins font
   - [ ] Dark theme defined in `main.dart`

2. **Theme toggle**:
   - Add a toggle option in the dashboard overflow menu (three-dot menu) or settings
   - Options: Light / Dark / System (follow device setting)
   - Default: System
   - [ ] Toggle option added to UI
   - [ ] Toggle switches theme in real-time

3. **Persist preference**:
   - Save theme choice to SharedPreferences (`theme_mode`: `light`, `dark`, `system`)
   - Read on app startup and apply
   - [ ] Preference saved
   - [ ] Preference loads on restart

4. **Audit screens for hardcoded colors**:
   - Search all screen files for hardcoded `Color(0xFF...)` or `Colors.white` / `Colors.black` that should respect theme
   - Replace with `Theme.of(context).colorScheme.surface`, `.onSurface`, etc.
   - Key files to check:
     - `dashboard_screen.dart`
     - `sales_screen.dart`
     - `inventory_screen.dart`
     - `reports_screen.dart`
     - `login_screen.dart`
     - `splash_screen.dart`
     - `ai_insights_widget.dart`
   - [ ] `dashboard_screen.dart` audited
   - [ ] `sales_screen.dart` audited
   - [ ] `inventory_screen.dart` audited
   - [ ] `reports_screen.dart` audited
   - [ ] `login_screen.dart` audited
   - [ ] `splash_screen.dart` audited
   - [ ] `ai_insights_widget.dart` audited
   - [ ] Other screens checked for hardcoded colors

---

### Step 5.3 — Animated Screen Transitions
Add smooth transitions between screens for a polished feel.

**Actions:**

1. **Custom page route transitions**:
   - Create a reusable `FadePageRoute` or `SlidePageRoute` builder
   - Apply to all `Navigator.push()` calls:
     - Standard navigation: fade transition (300ms)
     - Modal dialogs: slide-up from bottom
   - [ ] Custom route builder(s) created
   - [ ] Applied to main navigation calls

2. **Tab switch animations**:
   - Add subtle fade or cross-fade when switching bottom nav tabs
   - Use `AnimatedSwitcher` or similar widget in `home_screen.dart`
   - [ ] Tab switches have smooth animation

3. **Hero animations for product cards** (optional enhancement):
   - When tapping a product card in inventory → animate the card expanding into the detail/edit screen
   - Use Flutter's built-in `Hero` widget
   - [ ] Hero animation works on product cards (or skipped if not suitable)

---

### Step 5.4 — Testing

**Dashboard Charts:**
- [ ] Load demo data → Sales trend chart shows 7 data points
- [ ] Category chart shows correct slices for each product category
- [ ] Tap sales chart → Navigates to Reports (Sales tab)
- [ ] Tap category chart → Navigates to Reports (Inventory tab)
- [ ] Staff login → Charts not visible (manager-only)
- [ ] No data state: charts show "No data" gracefully (no crash)

**Dark Mode:**
- [ ] Toggle to dark mode → All screens render with dark background
- [ ] Text is readable (white/light on dark)
- [ ] Cards have appropriate contrast
- [ ] Charts render correctly in dark mode
- [ ] Toggle to light mode → Returns to original appearance
- [ ] Set to "System" → Follows device theme setting
- [ ] Restart app → Theme preference persisted
- [ ] Login screen looks good in both modes
- [ ] Splash screen looks good in both modes
- [ ] AI insights widget readable in dark mode

**Animations:**
- [ ] Navigating between screens has smooth fade transition
- [ ] Tab switches are smooth (no jarring snap)
- [ ] Dialogs slide up from bottom
- [ ] No jarring or broken animations anywhere

---

## Definition of Done
Dashboard has visual charts, dark mode works across all screens, transitions are smooth.

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
- [ ] Ready to proceed to Phase 6
