# Troubleshooting: Live Safety Score & Errors

If you see errors related to the Live Safety Score, use this guide.

---

## 1. "Target of URI doesn't exist" / red squiggles on imports

**Cause:** The IDE or analyzer can’t resolve packages (e.g. `package:usafe_front_end/...`, `package:google_maps_flutter/...`).

**Fix:**
- In the project root run: **`flutter pub get`**
- Restart the Dart Analysis Server (VS Code: Command Palette → "Dart: Restart Analysis Server")
- If it still fails, run **`flutter clean`** then **`flutter pub get`** again

---

## 2. Errors when opening the Safety Map screen

**Possible causes:**
- **Network:** Score calls Sunrise-Sunset and Overpass. No internet or firewall can cause timeouts.
- **Location:** Denied or unavailable location can lead to fallback (e.g. Colombo); the score should still compute.

**Fix:**
- Ensure the device/emulator has **internet** and (for real score at your position) **location permission**.
- Check the console/run window for the **exact exception** (e.g. `SocketException`, `TimeoutException`, `FormatException`). That will point to the failing API or parse.

---

## 3. Score always "Calculating…" or "Unable to update score"

**Cause:** One or more of the score steps are failing (APIs, parsing, or async flow).

**Fix:**
- Confirm **internet** is available.
- In **`lib/src/services/safety_apis.dart`** and **`lib/src/services/live_safety_score_service.dart`** add temporary `print()` or `debugPrint()` in the `catch` blocks and in `getScoreAt` to see which call fails.
- If you’re **outside Sri Lanka**, the app still computes a score (e.g. using defaults); if something else breaks, the printed error will say where.

---

## 4. Green / Orange / Red zones and "Active Trigger"

Behaviour as per the deep-dive:

- **Green (Safe):** Score ≥ 65. App stays in passive mode; mic off to save battery.
- **Orange (Caution):** Score 35–64.
- **Red (Danger):** Score &lt; 35. App can **automatically sharpen monitoring** (e.g. prompt to turn on Safety Mode / warm start for audio). The exact behaviour is in **`_onEnterDangerZone()`** in **`safety_map_screen.dart`** (currently shows a dialog to enable Safety Mode when entering Red).

If "Red zone" doesn’t trigger:
- Ensure the score actually drops below 35 (check the numeric score and pillar breakdown).
- Ensure **`_audioReady`** is true (audio model loaded) and **`!_isSafetyModeActive`** so the trigger can fire (see the `if (result != null && result.isDanger && ...)` condition in **`_updateLiveScore()`**).

---

## 5. Paste your exact errors for precise fixes

To fix your specific errors, please share:

1. The **exact error message(s)** (copy from the IDE or `flutter run` / `flutter analyze` output).
2. **When** it happens (e.g. on app start, when opening Safety Map, when score updates, when tapping something).
3. **Platform** (e.g. Android, iOS, web).

Then the implementation can be adjusted for your case (e.g. missing package, API failure, or logic bug).
