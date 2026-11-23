# Jodo Library (Flutter): Security & Responsive Review

Reviewed: 2026-11-23 · Branch: `Development` · Scope: `lib/`, `android/`, `scripts/`, `pubspec.yaml`

Priority: **P0** = fix before any public release · **P1** = fix soon · **P2** = improvement

---

## Implementation status (2026-11-23)

| Item | Status | What changed |
|------|--------|--------------|
| A1 HTTPS | ⚠️ Partial | `network_security_config.xml` now blocks plain HTTP for every host except `130.210.33.128`, `10.0.2.2` and `localhost`. **Still needed:** HTTPS on the backend, then delete the `<domain-config>` block. |
| A2 Env config | ✅ Done | `api_config.dart` reads `API_BASE_URL`, `ENTITY_ID`, `ENQUIRY_WEBHOOK_URL`, `ENQUIRY_WEBHOOK_SECRET` from `--dart-define` (defaults = current values). `devFixedOtp` removed. `env/*.json` git-ignored. |
| A3 Secure storage | ✅ Done | Token, phone, address, emergency contact, gender, DOB are in `flutter_secure_storage`. Existing values migrate automatically on first read, so nobody is logged out. |
| A4 Release build | ⚠️ Partial | Release signing reads `android/key.properties` when it exists; R8 minify + resource shrinking on. **Still needed:** create the keystore, change `applicationId` from `com.example.jodo_library`. |
| A5 Webhook | ✅ Done (redeploy script) | Formula-injection escaping, length limits, mobile check, 60 s rate limit per number, optional secret, no error leakage. App side: length limits, redirects only to Google hosts. |
| A6 Attendance location | ❌ Not done | Needs product/backend decision (real GPS + permission prompt). |
| A7 Error leakage | ✅ Done | Raw exceptions logged only in debug builds; users see fixed messages. |
| A8 Global 401 | ✅ Done | All requests go through `_AuthAwareClient`: a 401 on an authenticated call clears the session and returns to the welcome screen with a "session expired" message. The full `_send()` refactor is not done. |
| A9 URL allow-list | ✅ Done | `lib/utils/safe_url.dart`; owner links are normalised/validated on save and checked before launch. |
| A10 Hardening | ⚠️ Partial | 8 MB upload cap, cryptographically random `TransactionID`. Input `maxLength` on forms and backend checks are not done. |
| B1 Seat grids | ✅ Done | Seat grids use `SliverGridDelegateWithMaxCrossAxisExtent(60)`. Fixed 4-column amenity grids were kept as designed. |
| B2 Fixed sizes | ⚠️ Partial | QR viewfinder scales with screen (180–300 dp). Other fixed heights unchanged. |
| B3 Sheets + keyboard | ✅ N/A | No bottom sheet contains a text field. |
| B4 Tablet/landscape | ✅ Done | Portrait lock; app content capped at 640 dp and centred on wide screens. |
| B5 Overflow pass | ❌ Not done | Needs manual testing on a 320 dp device at 1.3× text. |
| B6 Text scale | ❌ Not done | Keep at 1.10 until B5 is done. |
| B7 `sizeOf` | ✅ Done | |
| B8 Split files | ❌ Not done | |

Verified: `flutter analyze` shows no new issues, `flutter test` passes, and `flutter build apk --release` succeeds (run with `--android-skip-build-dependency-validation` because of an existing AGP version mismatch; see below).

**Existing toolchain issue:** Flutter 3.50.1 requires Android Gradle Plugin ≥ 9.1.1, but `android/settings.gradle.kts` pins 9.1.0. Bump it there.

---

## Part A: Security

### A1. P0: All API traffic is plain HTTP to a raw IP
**Where:** `lib/services/api_config.dart:8`, `android/app/src/main/AndroidManifest.xml` (`android:usesCleartextTraffic="true"`)

`http://130.210.33.128:5000/api/v1` carries OTPs, JWT tokens, phone numbers, and student profiles unencrypted. Anyone on the same Wi-Fi (a library's shared network, for example) can read the tokens and take over sessions.

**Fix:**
- Put the backend behind a domain with TLS (Nginx/Caddy + Let's Encrypt, or a cloud load balancer) and use `https://api.<domain>/api/v1`.
- Remove `usesCleartextTraffic="true"`. If dev builds still need HTTP, allow it only in a debug `network_security_config.xml`:
  ```xml
  <!-- android/app/src/debug/res/xml/network_security_config.xml -->
  <network-security-config>
    <domain-config cleartextTrafficPermitted="true">
      <domain includeSubdomains="false">10.0.2.2</domain>
    </domain-config>
  </network-security-config>
  ```
- Optional, later: certificate pinning (for example `http_certificate_pinning`, or a custom `SecurityContext`).

### A2. P0: Environment config is hard-coded; no dev/prod separation
**Where:** `lib/services/api_config.dart`

The base URL, `entityId`, webhook URL, and `devFixedOtp = '4321'` are all compiled into every build. `devFixedOtp` isn't used in `lib/` today, but shipping it advertises that the backend accepts a universal OTP.

**Fix:**
- Use `--dart-define` / `--dart-define-from-file`:
  ```dart
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:5000/api/v1');
  static const enquiryWebhookUrl = String.fromEnvironment('ENQUIRY_WEBHOOK_URL');
  ```
  `flutter build apk --release --dart-define-from-file=env/prod.json` (add `env/*.json` to `.gitignore`).
- Delete `devFixedOtp` from the client.
- **Backend:** make sure the fixed OTP (`application-dev.yml`) can never be active under the prod profile.

### A3. P0: JWT and PII stored in plain SharedPreferences
**Where:** `lib/services/auth_storage.dart`

The token, phone, DOB, gender, emergency contact, and address are stored unencrypted (an XML file on Android). They can be read on rooted devices and through some backup paths.

**Fix:**
- Store the token (and ideally all PII) with `flutter_secure_storage` (Android Keystore / iOS Keychain).
- Keep only non-sensitive UI flags in SharedPreferences.
- `android:allowBackup="false"` is already set. Keep it.

### A4. P0: Release build is signed with the debug key; obfuscation is off
**Where:** `android/app/build.gradle.kts`

`signingConfig = signingConfigs.getByName("debug")`, `applicationId = "com.example.jodo_library"`, and no minify/shrink.

**Fix:**
- Create an upload keystore and a `key.properties` file (both are already git-ignored), and add a `release` signingConfig.
- Change `applicationId`/`namespace` to your own, such as `in.jodolibrary.app`. The Play Store rejects `com.example.*`.
- Enable `isMinifyEnabled = true` and `isShrinkResources = true` for release.
- Build with `flutter build appbundle --obfuscate --split-debug-info=build/symbols`.

### A5. P1: Google Sheets webhook is open to spam and formula injection
**Where:** `lib/services/enquiry_service.dart`, `scripts/google_sheet_enquiry_webhook.js`

- The webhook is deployed with "Anyone" access and its URL is in the APK, so anyone can flood the sheet.
- `sheet.appendRow([...])` writes user text as-is. A name or message like `=HYPERLINK("http://evil","click")` or `=IMPORTXML(...)` runs as a formula when the sheet is opened (spreadsheet/CSV injection).

**Fix (Apps Script):**
```js
function safe(v) {
  v = String(v || '').slice(0, 1000);
  return /^[=+\-@\t\r]/.test(v) ? "'" + v : v;
}
// appendRow([safe(timestamp), safe(name), ...])
```
- Add a shared-secret field (checked in `doPost`), length limits, and simple rate limiting (`CacheService` per mobile number).
- Better: send enquiries to your own backend (`POST /enquiries`) with validation and rate limiting, and have the backend forward them to the sheet.

### A6. P1: Attendance location is hard-coded, so the geofence is meaningless
**Where:** `lib/services/api_service.dart` → `scanAttendanceQr` (`latitude ?? 25.6093`, `longitude ?? 85.1376`). `ownerSetup` does the same.

The app always sends Patna coordinates, so a student can punch in from anywhere using a photo of the QR code.

**Fix:**
- Get the real location with `geolocator` and send `null` or fail if permission is denied. Never send fake defaults.
- **Backend:** validate distance from the library, use short-lived rotating QR codes (you already have `dynamic-qr`), and reject replayed payloads.
- Treat client-sent location as a weak signal only. Mock-location detection helps on Android.

### A7. P1: Raw exception text shown to users
**Where:** `api_service.dart` `_formatNetworkError` (`'$defaultPrefix: $e'`), `enquiry_service.dart` (`'Could not connect to enquiry server. ($e)'`), `library_details_screen.dart:179` (shows the URL)

These leak internal hostnames, IPs, stack details, and parse errors.

**Fix:** Show friendly fixed messages. Log `e` with `debugPrint` (or Crashlytics/Sentry) only when `kDebugMode`.

### A8. P1: Fragile response parsing and session handling
**Where:** every `ApiService` method does `jsonDecode(response.body) as Map<String, dynamic>`

- A 502 HTML page from a proxy causes a `FormatException`, which is then shown as "Could not connect…".
- Only `getMe()` clears the session on 401. Other endpoints keep using an expired token, and the user sees random errors.

**Fix:** Move the repeated code into one `_send()` helper that:
1. checks `content-type` before decoding,
2. handles 401/403 in one place (clear the session and navigate to login through `NetworkService.navigatorKey`),
3. maps errors to user-safe messages.

This also removes about 1,000 lines of duplicated code from `api_service.dart`.

### A9. P1: URLs from server data are launched without checks
**Where:** `library_details_screen.dart:161` `_launchUrlString`, `partner_home_screen.dart:3978`, `owner_business_profile_screen.dart`

Owner-entered `googleMapsUrl`, website, and other links are opened with `launchUrl` without checking the scheme. A malicious owner could add `intent://`, `file://`, or other schemes.

**Fix:** Allow only `https`, `tel`, `geo`, `mailto`, and `whatsapp` before launching:
```dart
const _allowed = {'https', 'tel', 'geo', 'mailto', 'whatsapp'};
if (!_allowed.contains(uri.scheme)) return;
```
Validate these URLs on the backend when the owner saves them too.

### A10. P2: Upload and input hardening
- `uploadLibraryPhoto` doesn't check file size or type on the client. Add a size cap (for example 5 MB), and on the **backend** check MIME type and magic bytes, strip EXIF data (it includes GPS), and serve files from a separate domain or bucket.
- Most `TextField`s have no `maxLength` or `inputFormatters`. Add limits for name, address, and message, and digits-only for phone. The backend must validate these as well.
- `Image.network` loads URLs from the server. Make sure the backend returns HTTPS URLs only. Consider `cached_network_image` with `errorBuilder`.
- `TransactionID` uses `millisecondsSinceEpoch`, which collides under parallel calls. Use a UUID.

### A11. P2: Repo hygiene
- `.fvmrc` is untracked. Commit it so everyone uses the same Flutter version.
- Run `git log -p -S "130.210.33.128"` and similar searches before making the repo public. The IP and webhook URL are already in history, so plan to rotate them (new server IP/domain and a new Apps Script deployment).
- Add `flutter analyze` and a dependency-audit step to CI.

---

## Part B: Responsive / Layout

The app clamps text scale and uses `isScrollControlled` sheets, which is a good start. The main problems are fixed grid counts, fixed pixel sizes, and no tablet or landscape handling.

### B1. P1: Seat grids use a fixed `crossAxisCount`
**Where:**
- `partner_home_screen.dart:1621` (6 columns)
- `library_details_screen.dart:1848` (6), `:1362` (4)
- `owner_business_profile_screen.dart:757` (3), `:907` (4)
- `partner_home_screen.dart:4082` (4)
- `student_home_screen.dart:2143` (7, calendar; fine as-is)

On a 320 dp phone, 6 columns leave about 40 dp per seat, below the 48 dp touch target, and text overflows. On a tablet, the seats are oversized.

**Fix:** Use `SliverGridDelegateWithMaxCrossAxisExtent`:
```dart
gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 64,   // seat tile ~56–64dp
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  childAspectRatio: 1,
),
```

### B2. P1: Fixed pixel widths and heights
**Where:** `student_home_screen.dart:4378` (QR scanner 220×220), `:2418`, `:2719`; `partner_home_screen.dart:3811-3816` (220×136 image), `:4521/4546/4574` (220/200 heights), `:3797`

**Fix:**
- QR scanner: `AspectRatio(aspectRatio: 1, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 320), ...))`, or size it as `min(width, height) * 0.6`.
- Images: wrap in `AspectRatio(16/10)` inside `Flexible`/`Expanded` instead of a fixed `width: 220`.
- Chart and card heights: use `LayoutBuilder` and clamp, for example `(constraints.maxWidth * 0.5).clamp(140, 260)`.

### B3. P1: Bottom sheets with fixed `height: size.height * 0.75/0.85`
**Where:** `partner_home_screen.dart:4232`, `:6661`; `owner_business_profile_screen.dart:423`; `library_details_screen.dart:1171`

When the keyboard opens inside these sheets (edit dialogs, search), the content is covered or overflows. Landscape breaks them too.

**Fix:** Use `DraggableScrollableSheet`, or:
```dart
Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
  child: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
    child: SingleChildScrollView(child: ...),
  ),
)
```
Also add `useSafeArea: true` to `showModalBottomSheet`.

### B4. P1: No tablet, foldable, or landscape layout
Only `otp_screen.dart` uses `LayoutBuilder`. On tablets and Chromebooks, every screen stretches edge to edge.

**Fix:**
- Add breakpoints in `lib/theme/app_theme.dart`:
  ```dart
  class Breakpoints { static const compact = 600.0; static const medium = 840.0; }
  ```
- Wrap screen bodies in `Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 600), child: ...))` for forms (mobile, OTP, setup, enquiry).
- On ≥ 840 dp, switch `bottomNavigationBar` to a `NavigationRail` in `partner_home_screen` and `student_home_screen`.
- If you don't support landscape yet, lock it: `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` in `main()`.

### B5. P1: Rows that can overflow
`partner_home_screen.dart` has 148 `Row(`s and about 89 `Expanded`/`Flexible`/`overflow`. `student_home_screen.dart` has 81 and 53. Rows with long library names, addresses, or amounts (₹) overflow on small phones and with larger text.

**Fix:** Wrap text in rows with `Expanded`/`Flexible` and add `maxLines` + `overflow: TextOverflow.ellipsis`. Use `Wrap` for chip and button rows.
**Test:** run on a 320×568 emulator (or Device Preview) at text scale 1.3 and look for yellow and black overflow stripes.

### B6. P2: Text scale clamp is too strict (accessibility)
**Where:** `main.dart` clamps `textScaler` to `0.85–1.10`

Low-vision users who set larger system fonts get almost no increase. Google Play accessibility guidance expects support up to about 1.3 or higher.

**Fix:** Raise it to `maxScaleFactor: 1.3` once B5 is done.

### B7. P2: `MediaQuery.of(context)` causes extra rebuilds
Use `MediaQuery.sizeOf(context)` / `MediaQuery.viewInsetsOf(context)` so widgets rebuild only when the value they use changes.

### B8. P2: Very large screen files
`partner_home_screen.dart` (7,475 lines) and `student_home_screen.dart` (4,798 lines) make responsive changes risky and slow to rebuild.

**Fix:** Split each tab and modal into its own widget file (for example `screens/partner/seats_tab.dart`, `members_tab.dart`, `widgets/seat_grid.dart`). A shared `SeatGrid` widget would also remove the near-duplicate grids from B1.

---

## Suggested order of work

| # | Task | Priority |
|---|------|----------|
| 1 | HTTPS backend + remove cleartext (A1) | P0 |
| 2 | `--dart-define` env config, remove `devFixedOtp` (A2) | P0 |
| 3 | `flutter_secure_storage` for the token (A3) | P0 |
| 4 | Release signing, app ID, obfuscation (A4) | P0 |
| 5 | Sanitize + protect the Sheets webhook (A5) | P1 |
| 6 | Real geolocation for attendance (A6) | P1 |
| 7 | Central `_send()` helper: safe errors + global 401 (A7, A8) | P1 |
| 8 | URL scheme allow-list (A9) | P1 |
| 9 | Seat grids → `MaxCrossAxisExtent` (B1) | P1 |
| 10 | Bottom sheets keyboard-safe (B3) + fixed sizes (B2) | P1 |
| 11 | Max-width wrapper / orientation lock (B4) | P1 |
| 12 | Overflow pass on 320 dp + 1.3× text (B5, B6) | P1–P2 |
| 13 | Split large screen files (B8) | P2 |
