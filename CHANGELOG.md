# Changelog

## 0.0.1 — preview

First preview. Not an official release; not published to pub.dev.

- Wraps the OneS1ght iOS SDK `0.2.2` (Swift Package Manager) and Android SDK `0.0.9` (Maven Central).
- Dart API follows the iOS SDK names. Native callbacks are `Stream`s.
- Native errors arrive as `OneS1ghtException` with the native SDK's error code (`E1001` …), same on both platforms.
- iOS: Swift Package Manager only (Flutter 3.44+). The podspec stops `pod install` with instructions.
- Android: `MainActivity` must extend `FlutterFragmentActivity` for `requestPermission()`.
