# Arul GPS Camera — v1.1

Android camera app that burns location, address, time and bearing into every
photo it takes. Built for field inspection work where the photo itself has to
carry the proof.

## What lands on the photo

A maps-style card across the bottom of the image, burned into the pixels:

- Place name in bold, then the street address (needs internet; coordinates work
  offline either way)
- `Lat 11.101568° N   Long 79.681434° E`
- Day, date, time and time zone
- Altitude, GPS accuracy (± metres), compass bearing
- Map thumbnail of the spot with a red pin and a compass badge
- QR code — scanning it opens that exact point in Google Maps

The Arul name and mark stay inside the app UI and icon. Nothing branded is
burned onto the photo.

No EXIF geo-tag is written. The stamp survives WhatsApp, screenshots and print.

## Repo layout

Only source is tracked. The Android project files (gradle wrapper,
`MainActivity`, `res/`) are generated during the build, so the repo stays small
and does not break when the Flutter version moves.

```
lib/
  main.dart
  theme.dart              brand colours, version constant
  strings.dart            English + Tamil UI text
  screens/                camera, photos, settings
  widgets/                live GPS readout, grid overlay
  services/
    location_service.dart position stream, throttled geocoding, compass
    map_tile_service.dart OpenStreetMap tile fetch + disk cache
    stamp_service.dart    card drawing on a Flutter Canvas, JPEG encode in an
                          isolate
    photo_store.dart      dated app folder + gallery album copy
    settings_service.dart
assets/logo/              app icon and adaptive foreground
assets/fonts/             Inter (Regular, Medium, SemiBold, Bold)
android/app/src/main/AndroidManifest.xml
.github/workflows/build.yml
```

## Build the APK

1. Create the repo `arul-gps-camera` under the `edmmyld-netizen` account.
2. Push everything in this folder to the `main` branch.
3. GitHub Actions builds automatically. Actions tab → latest run → Artifacts →
   `ArulGPSCamera-v1.1-apk`.

To trigger a build without a code change: Actions → *Build Arul GPS Camera APK*
→ Run workflow.

## Settings

Language (English default, Tamil option), map thumbnail on/off, QR on/off,
compass on/off, address on/off, 24-hour time, grid lines, photo width (1280 /
1920 / 2560 / 4000 px — smaller shares faster on WhatsApp).

The card itself is always written in English, whatever the UI language is, so
it reads the same to whoever receives the photo.

## Where photos go

- App folder, one folder per date, for the in-app Photos screen
- Phone gallery, album **Arul GPS Camera**

Deleting inside the app removes the app copy only. The gallery copy stays.

## Notes

- Package id: `com.arulsundaresan.arul_gps_camera`
- minSdk 23 (Android 6.0 and up), built on Flutter 3.32.x
- Both portrait and landscape are supported; the card scales to the captured
  frame width, so it looks the same either way
- The card is drawn with Flutter's own text engine using bundled Inter, not the
  image package's bitmap fonts
- The compass is computed in-app from the accelerometer and magnetometer
  (`sensors_plus`), tilt compensated, so no compass plugin is needed. It reads
  magnetic north.
- Map tiles © OpenStreetMap contributors, cached on device after first use, so
  a spot visited before still draws its map offline
- The release APK from this workflow is debug-signed. For Play Store upload a
  real keystore has to be added as repository secrets — separate step.
