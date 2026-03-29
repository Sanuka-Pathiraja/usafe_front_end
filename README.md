# USafe — Intelligent Personal Safety App

> Official website: [www.usafe.lk](https://www.usafe.lk)

USafe is a Flutter-based mobile safety application designed to help users stay safe through real-time threat detection, emergency response tools, safe route navigation, and community-powered danger reporting.

---

## Features

### SOS & Emergency Response
- **Hold-to-activate SOS button** with glassmorphism UI — triggers an emergency session that alerts contacts and logs details to the database.
- **Silent call** — discreetly places a call to a trusted contact without revealing the action on-screen.
- **Emergency contacts** — minimum 3 contacts required; app enforces this even when minimised.
- **SOS 911 toggle** — option in Settings to disable direct 911 dialling (configurable per region).
- **Emergency session logging** — session details (location, time, contacts notified) are saved to the backend.

### AI-Powered Threat Detection
- **Scream / distress audio detection** — on-device ML model listens for signs of danger.
- **Voice danger detection** — multiple audio sources supported for broad device compatibility.
- **Real-time safety score** — dynamic score calculated from environmental data, shown on the home screen with a ripple-effect visual indicator.

### Safe Route Navigation
- **Mapbox-powered routing** — calculates the safest path to a destination.
- **Danger zone overlay** — backend-driven red zones with dual-layer glow rendered on the map.
- **Pulsing danger zone animation** — animated overlays highlight hotspots on map load.
- **Auto-fit camera** — camera automatically frames the route and visible danger zones.
- **Collapsible map legend** — live zone count and route source status, collapsible to reduce clutter.
- **Fallback routing** — standard destination route shown when a safe-path alternative is unavailable.
- **Safe Path scheduler** — plan and schedule future safe-path journeys.
- **Guardian mode** — share your live route with a trusted contact who can monitor your journey.

### Community & Reporting
- **Community reports portal** — browse danger reports submitted by other users on a map.
- **Submit a report** — report unsafe locations directly from the app.
- **My Reports** — view and manage your own submitted reports.

### Contacts
- **Phone-book integration** — add trusted contacts from your device contacts list.
- **Contact alert bottom sheet** — quick alert UI to notify specific contacts.
- **Multiple contacts to portal** — send emergency details to multiple contacts simultaneously.

### Onboarding & Guides
- **Welcome / privacy consent screens** — shown on first launch.
- **Permissions onboarding** — step-by-step guide to grant required permissions.
- **Emergency contacts setup** — guided flow to add the required minimum contacts.
- **In-app page guides** — contextual showcase tours on key screens (Silent Call, Contacts, etc.) with a Settings toggle to re-enable them.

### Notifications
- **Firebase push notifications** — receive safety alerts and updates in the background.
- **Local notifications** — triggered for low safety score and other in-app events.

### Profile & Settings
- **Profile screen** — view and edit user details.
- **Settings screen** — manage app preferences, log out, toggle page guides, and configure SOS options.
- **Medical ID** — store personal medical information for emergency responders.
- **Safety score detail page** — drill down into score components.

### Other
- **Payment / subscription screen** — in-app payment via WebView checkout.
- **Help & Support screen** — contact support and access the privacy policy.
- **Privacy screen** — full privacy policy viewer.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart, SDK ≥ 3.0) |
| Maps & Routing | Mapbox, Google Maps |
| Backend / Auth | Firebase (Auth, Messaging, Firestore) |
| Notifications | Firebase Cloud Messaging + flutter_local_notifications |
| Audio / ML | On-device audio analysis service (scream & voice detection) |
| Location | geolocator, geocoding |
| Contacts | flutter_contacts |
| Telephony | flutter_phone_direct_caller, flutter_sms |
| State / Prefs | shared_preferences |

---

## Run Locally

1. **Install Flutter** (stable channel) and verify with `flutter doctor`.
2. **Get dependencies:**
   ```bash
   flutter pub get
   ```
3. **Configure API keys:**
   - Copy `lib/src/config/app_config.example.dart` to `lib/src/config/app_config.dart` and fill in your keys.
   - Set your Google Maps API key in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml).
4. **Run:**
   ```bash
   flutter run
   ```

---

## Permissions

| Permission | Purpose |
|-----------|---------|
| `READ_CONTACTS` | Import trusted contacts from phone book |
| `ACCESS_FINE_LOCATION` | Real-time location for safe routing and SOS |
| `RECORD_AUDIO` | AI scream / distress audio detection |
| `CALL_PHONE` | Silent call and SOS direct dial |
| `SEND_SMS` | Alert trusted contacts via SMS |
| `RECEIVE_BOOT_COMPLETED` | Restart background monitoring after reboot |

---

## Notes

- If you see an older build, run `flutter clean` then `flutter run`.
- Maps will not render without valid API keys.
- The minimum 3 emergency contacts rule is enforced at runtime — the app will prompt the user if fewer are set.
- Audio detection requires `RECORD_AUDIO` permission; the detector page will show a warning if denied.
