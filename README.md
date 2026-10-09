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

## Keys, file sources, and app lock

- On Android and iOS, choose cover images and payloads from either the photo
  gallery or the system Files picker.
- Private identities can be exported to and imported from a password-encrypted
  `.stegkey` backup. The backup uses Argon2id and AES-256-GCM; keep its password
  safe, because it cannot be recovered.
- Optional app protection uses a password, with biometrics available on devices
  that support them. The password is stored as a key-derived verifier in secure
  platform storage.

## Running

The **Liquid Glass** appearance is available under Settings → Design language.
It uses shader-based glass surfaces and requires Flutter 3.41 or newer.

```sh
flutter pub get
flutter run -d windows   # or -d android / -d ios
flutter test