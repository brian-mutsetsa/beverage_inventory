# Phase 2: Security Hardening

**Status**: NOT STARTED
**Depends on**: Phase 1 (Bug Fixes & Verification)
**Complexity**: Medium
**New files**: 2-3 | **Modified files**: 6-8 | **New packages**: 2 (`crypto`, `flutter_secure_storage`)

---

## Goal
Bring authentication and data security up to a production-acceptable standard. PINs hashed, sessions timeout, sensitive data in secure storage.

---

## Steps

### Step 2.1 — Hash PINs Before Storage
PINs are currently stored as plaintext in SQLite and synced as plaintext to Supabase. This is a critical security gap.

**Actions:**

1. **Add package** — Add `crypto` to `pubspec.yaml` and run `flutter pub get`
   - [ ] Package added and resolved

2. **Create security helper** — Create `lib/helpers/security_helper.dart`:
   - `hashPin(String pin)` → returns SHA-256 hex string
   - `verifyPin(String inputPin, String storedHash)` → hashes input, compares to stored hash, returns bool
   - [ ] File created with both methods
   - [ ] Methods tested (unit test or manual verification)

3. **Update database_helper.dart — createUser()**:
   - Before inserting, hash the PIN using `SecurityHelper.hashPin()`
   - The `User` object passed in has the plaintext PIN → hash it before `db.insert()`
   - [ ] `createUser()` hashes PIN before insert

4. **Update database_helper.dart — getUserByPin()**:
   - Hash the input PIN first, then query `WHERE pin = hashedValue`
   - [ ] `getUserByPin()` hashes input before query

5. **Update database_helper.dart — generateUniquePIN()**:
   - When checking uniqueness, hash the candidate PIN before querying
   - [ ] `generateUniquePIN()` works with hashed PINs

6. **Update manager_auth_screen.dart**:
   - On company registration, hash the manager PIN before saving
   - The success dialog still shows the PLAINTEXT PIN to the user (so they can write it down)
   - Only the stored/synced version is hashed
   - [ ] Manager registration hashes PIN before storage
   - [ ] Success dialog still shows readable PIN

7. **Update user_management_screen.dart**:
   - Hash PIN on staff creation
   - Hash PIN on PIN reset
   - Success dialogs still show plaintext for the user to copy
   - [ ] Staff creation hashes PIN
   - [ ] PIN reset hashes new PIN
   - [ ] Dialogs show readable PIN

8. **Migration for existing data** — Write a one-time migration:
   - On app startup (or DB upgrade), check if PINs are already hashed
   - If not, hash all existing plaintext PINs in the users table
   - Strategy: check if PIN length matches SHA-256 hex length (64 chars) — if shorter, it's plaintext
   - [ ] Migration logic written
   - [ ] Migration tested with existing demo data

9. **Update Supabase sync**:
   - Ensure `pushUser()` in `sync_service.dart` sends hashed PINs to cloud (never plaintext)
   - [ ] Supabase sync pushes hashed PINs

---

### Step 2.2 — PIN Complexity Validation
Prevent weak PINs like `111111`, `123456`, `AAAAAA`.

**Actions:**

1. **Add validation to security_helper.dart**:
   - `isWeakPin(String pin)` → returns bool
   - Reject if all characters are the same (e.g., `AAAAAA`, `111111`)
   - Reject common sequences (`123456`, `ABCDEF`, `654321`)
   - Require at least 1 letter and 1 digit
   - [ ] `isWeakPin()` method created
   - [ ] Covers: all-same, sequential, letter+digit requirement

2. **Apply in generateUniquePIN()**:
   - After generating a candidate PIN, check `isWeakPin()` → if weak, regenerate
   - [ ] Weak PIN rejection integrated into generation loop

3. **Apply in any manual PIN entry** (if setup_screen.dart is kept):
   - Show validation error: "PIN is too simple. Use a mix of letters and numbers."
   - [ ] Manual entry validated (or N/A if setup screen removed in Phase 1)

---

### Step 2.3 — Session Timeout
Auto-logout after period of inactivity to prevent unauthorized access on unattended devices.

**Actions:**

1. **Create session manager** — Create `lib/services/session_manager.dart`:
   - `lastActivity` timestamp, updated on every user interaction
   - `timeoutDuration` — configurable, default 15 minutes
   - `resetTimer()` — call on any user tap/interaction
   - `isExpired()` → returns bool (current time - lastActivity > timeout)
   - `startMonitoring()` — periodic check (every 30 seconds)
   - `stopMonitoring()` — cleanup on logout
   - [ ] File created
   - [ ] Timer logic works correctly

2. **Wrap HomeScreen with activity detection**:
   - Use a `GestureDetector` or `Listener` at the top of the widget tree (in `home_screen.dart`)
   - On any tap/pointer event → `SessionManager.resetTimer()`
   - [ ] Activity listener wrapping HomeScreen

3. **Handle timeout event**:
   - When timeout triggers: show "Session expired — please log in again" dialog
   - Navigate to login screen, clear current user state
   - [ ] Timeout dialog shows
   - [ ] Navigation to login works
   - [ ] User state cleared

4. **Persist timeout preference**:
   - Store manager's chosen timeout duration in SharedPreferences
   - Options: 5 min, 15 min, 30 min, Never
   - Add setting option in dashboard menu (manager only)
   - [ ] Timeout preference saved/loaded
   - [ ] Manager can change timeout duration

---

### Step 2.4 — Secure Storage for Sensitive Data
Move sensitive values from plain SharedPreferences into encrypted storage.

**Actions:**

1. **Add package** — Add `flutter_secure_storage` to `pubspec.yaml`
   - [ ] Package added and resolved

2. **Create or update a storage helper** (or use FlutterSecureStorage directly):
   - Migrate these values to secure storage:
     - `companyId`
     - Any cached user session data
   - [ ] Secure storage wrapper created (if needed)

3. **Update splash_screen.dart**:
   - Read `companyId` from secure storage instead of SharedPreferences
   - [ ] Splash screen reads from secure storage

4. **Update login_screen.dart**:
   - Read/write company context from secure storage
   - [ ] Login screen uses secure storage

5. **Update manager_auth_screen.dart**:
   - Write `companyId` to secure storage on registration
   - [ ] Registration saves to secure storage

6. **Keep non-sensitive values in SharedPreferences**:
   - `has_seen_tutorial` — fine in SharedPreferences (not sensitive)
   - Theme preference — fine in SharedPreferences
   - Timeout duration — fine in SharedPreferences
   - [ ] Only sensitive values migrated, non-sensitive stay put

---

### Step 2.5 — Testing

**PIN Hashing:**
- [ ] Register new company → Inspect SQLite: PIN is a 64-char hex hash (not plaintext)
- [ ] Login with correct PIN → Access granted
- [ ] Login with wrong PIN → Access denied
- [ ] Create staff member → PIN shown in dialog (plaintext), but DB has hash
- [ ] Reset PIN → Old PIN stops working, new PIN works, DB has new hash
- [ ] Load demo data → All demo users have hashed PINs
- [ ] Existing plaintext PINs migrated to hashes on app upgrade

**PIN Validation:**
- [ ] Generated PINs are never all-same-character
- [ ] Generated PINs always contain at least 1 letter and 1 digit

**Session Timeout:**
- [ ] Set timeout to 5 min (for testing) → Wait idle → Session expires → Redirected to login
- [ ] Interact with app before timeout → Timer resets, no logout
- [ ] Manager changes timeout to 30 min → Preference persists after restart

**Secure Storage:**
- [ ] companyId stored in secure storage (not plain SharedPreferences)
- [ ] App starts correctly reading from secure storage
- [ ] On fresh install: no secure storage values → routes to registration (as before)

---

## Definition of Done
All items above are checked off. PINs are hashed everywhere, session timeout works, sensitive data is in secure storage.

---

## Issues Found During This Phase
*(Log any unexpected issues here as they arise)*

| # | Issue | File(s) | Status |
|---|-------|---------|--------|
| | | | |

---

## Phase Sign-Off
- [ ] All steps completed
- [ ] All tests passed
- [ ] No blocking issues remaining
- [ ] Ready to proceed to Phase 3
