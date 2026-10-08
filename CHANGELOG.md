# Changelog

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
