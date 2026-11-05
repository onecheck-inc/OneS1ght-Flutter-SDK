# Changelog

## 0.0.6 — preview

Native SDKs updated: iOS 0.2.7 → 0.2.8, Android 0.0.12 → 0.0.13. No Dart API changes.

- **Zone dwell now reaches the server:** when a zone has a dwell time set, dwell is sent to the server and dwell events
  from the console arrive through triggers. The on-device dwell callback is unchanged.

## 0.0.5 — preview

Native SDKs updated: iOS 0.2.2 → 0.2.7, Android 0.0.9 → 0.0.12. No Dart API changes.

- **Positions no longer move to the next user:** when the profile changes, unsent positions of the previous user are
  discarded (`E5006`), and positions are not buffered while no profile is set.
- **iOS:** the positioning engine's diagnostic logs moved out of the app's `Documents` into its temporary folder and are
  cleared on initialization. Three symbolic links appear in the app's `Documents`.
- **Android:** position logs from the engine no longer reach logcat in apps with minify enabled.
- Includes the native positioning and stability fixes released since the previous pins.
- Use `^0.0.5` — in Dart a caret on `0.0.x` allows only that patch.

## 0.0.4 — preview

No plugin code or behavior changes.

- **Coding-agent support (MCP):** added `Snippets/flutter.json` (12 steps, Dart) and `Migrations/flutter.json`, read by the
  OneS1ght SDK MCP server (`onesight_snippet` / `onesight_migrate` with `platform: flutter`).
- README: Xcode 27+ build requirement, profile example creates once and reuses the stored id (`ageBand`, same keys as
  the native SDKs), and `permission_handler` must be imported with a prefix (`PermissionStatus` name clash).
- Use `^0.0.4` — in Dart a caret on `0.0.x` allows only that patch.

## 0.0.3 — preview

- iOS: SDK error `message` is now a readable sentence with the code (`"… (E1001)"`), the same shape as Android.
  It was the bare case name (`notInitialized`). `code`, `kind` and `name` are unchanged.
- Note: `^0.0.2` does not pick up 0.0.3 — in Dart a caret on `0.0.x` allows only that patch. Use `^0.0.3`.

## 0.0.2 — preview

First release on pub.dev.

- Install with `flutter pub add ones1ght_sdk` (git dependency no longer needed).
- Main library is now `package:ones1ght_sdk/ones1ght_sdk.dart`. The 0.0.1 path `ones1ght.dart` still works.
- No API or behavior changes. Native SDKs unchanged (iOS `0.2.2`, Android `0.0.9`).

## 0.0.1 — preview

First preview, distributed as a git dependency.

- Wraps the OneS1ght iOS SDK `0.2.2` (Swift Package Manager) and Android SDK `0.0.9` (Maven Central).
- Dart API follows the iOS SDK names. Native callbacks are `Stream`s.
- Native errors arrive as `OneS1ghtException` with the native SDK's error code (`E1001` …), same on both platforms.
- iOS: Swift Package Manager only (Flutter 3.44+). The podspec stops `pod install` with instructions.
- Android: `MainActivity` must extend `FlutterFragmentActivity` for `requestPermission()`.
