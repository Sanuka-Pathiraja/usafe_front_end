# USafe Front End

## Run Locally

1. Install Flutter (stable) and verify with `flutter doctor`.
2. Get dependencies:
   - `flutter pub get`
3. Add your Google Maps API key (Android):
   - Set `YOUR_GOOGLE_MAPS_API_KEY` in [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml#L1)
4. Run:
   - `flutter run`

## Permissions

This app uses contacts to let you add trusted contacts from your phone book.
The first time you enter the app, an authorization screen will request access.

Android:

- `android.permission.READ_CONTACTS` is required (already declared).

## Notes

- If you see an older build, run `flutter clean` and then `flutter run`.
- For Maps to work, you must provide a valid API key.
