# STEGSHARE

Local-first steganography: hide several text messages and/or files inside an image,
encrypt them with a password or a recipient's public key, and save a PNG. No accounts,
no server, no cloud, no telemetry. Everything runs offline on the device.

## Platforms

| Platform | Status |
|----------|--------|
| Android  | supported |
| iOS      | supported |
| Windows  | supported (drag & drop, no camera QR scanning yet — TODO) |
| macOS / Linux | not configured, but nothing in the architecture prevents it |

## Running

```sh
flutter pub get
flutter run -d windows   # or -d android / -d ios
flutter test