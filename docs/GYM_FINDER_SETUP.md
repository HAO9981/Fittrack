# Gym Finder setup

Gym Finder now uses Google Maps Flutter for the map, Android location permissions for the current position, and Google Places API (New) Nearby Search for real place names, addresses, ratings, and map markers.

## 1. Enable Google APIs

In Google Cloud Console, select or create a project and enable:
- Maps SDK for Android
- Places API (New)

Attach billing to the project if Google Cloud requires it for these APIs.

## 2. Configure the Android Maps key

Add this line to your local `android/local.properties` file (do not commit this file or the key):

```properties
GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_API_KEY
```

The Gradle configuration reads this value and supplies it to Android's Google Maps metadata.

## 3. Configure the Places search key

Run the app with the same restricted key supplied at build time:

```bash
flutter pub get
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_RESTRICTED_API_KEY
```

The `--dart-define` value is used for the Places API request. Keep it consistent with the Android key.

## 4. Restrict and protect the key

- Restrict the key to the Android app package `com.lwh.fittrack` and your signing certificate SHA-1 for Maps SDK for Android.
- Restrict API access to only the APIs this app needs.
- Set billing alerts and usage quotas.
- Do not commit real API keys to GitHub.
- A key embedded in a client app can be extracted. For production, proxy Places requests through a trusted backend and keep the server key there; use separate keys for Android Maps and server-side Places where possible.

## 5. Test on a real Android device

1. Install the app and allow location permission.
2. Turn on device Location Services.
3. Confirm the Google Cloud APIs are enabled and the key restrictions match the app.
4. Open Gym Finder and tap refresh. The screen searches within 8 km and displays results returned by Google Places; ratings appear only when Google provides them.
5. If the map is blank or search fails, check the API key restrictions, Places API (New), billing, internet access, and location permission.

No sample gyms are hardcoded as real locations. If the key is missing, Gym Finder displays a setup message rather than fabricated results.
