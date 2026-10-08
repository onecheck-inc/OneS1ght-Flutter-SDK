# OneS1ght SDK — Flutter (preview)

**English** | [한국어](README.ko.md)

> ⚠️ **Preview.** The API may change before 1.0. The officially supported SDKs are the native
> [iOS](https://github.com/onecheck-inc/OneS1ght-iOS-SDK) and
> [Android](https://github.com/onecheck-inc/OneS1ght-Android-SDK) SDKs.

Indoor location intelligence SDK for Flutter apps. It is a thin wrapper around the OneS1ght iOS and
Android SDKs: positioning, zone enter / exit / dwell judgement, upload and retries all run in the native
SDK. Dart only forwards calls and turns the results into Dart types — so the SDK keeps working the same
way when the app goes to the background and Dart pauses.

The Dart API follows the iOS SDK names. Native callbacks (`onZoneEnter`, `onPosition`, …) are Dart
`Stream`s with the same names.

---

## Requirements

| Item | Requirement |
|---|---|
| Flutter | **3.44+** (Swift Package Manager on — the default since 3.44) |
| iOS | Package: iOS 18.0+ · Positioning: **iOS 27.0+**, iPhone with a UWB chip |
| Android | Package: `minSdk 26` · `compileSdk 37` · Positioning: **Android 17 (API 37)+**, UWB DL-TDoA capable device |
| Native SDKs (pinned) | iOS `0.2.2` · Android `0.0.9` |

On devices that cannot position, the app runs normally; only positioning stays inactive.

You also need an SDK key (`ock_sdk_…`, OneS1ght Console → **Mobile SDK**), and buildings, floors,
locators and zones set up for your tenant.

---

## Step 1: Add the plugin

```sh
flutter pub add ones1ght_sdk
```

or in `pubspec.yaml`:

```yaml
dependencies:
  ones1ght_sdk: ^0.0.2
```

```dart
import 'package:ones1ght_sdk/ones1ght_sdk.dart';
```

> `package:ones1ght_sdk/ones1ght.dart` (the 0.0.1 path) still works.

### iOS

**Swift Package Manager only.** CocoaPods is not supported — the positioning engine ships as dynamic
frameworks that CocoaPods does not embed, and the app would crash at launch. If Swift Package Manager is
off, `pod install` stops with a message telling you to run:

```sh
flutter config --enable-swift-package-manager
```

Set the iOS deployment target to **18.0** (`ios/Runner.xcodeproj` → `IPHONEOS_DEPLOYMENT_TARGET`).

Add these to `ios/Runner/Info.plist`. The first three crash the app when the permission is requested
if they are missing:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to find your position in the store.</string>
<key>NSNearbyInteractionUsageDescription</key>
<string>Used for precise UWB positioning.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to find nearby positioning devices.</string>
<key>NSLocationTemporaryUsageDescriptionDictionary</key>
<dict>
    <key>Positioning</key>
    <string>Used to calculate your precise indoor position.</string>
</dict>
```

> ⚠️ The key inside `NSLocationTemporaryUsageDescriptionDictionary` must be exactly **`Positioning`**.
> Otherwise iOS ignores the request with no error and no log.

**iOS 27.2+: location permission must be "Always".** The engine detects the floor with BLE beacon region
monitoring, and from iOS 27.2 the system keeps reporting "outside" under "While Using". Add
`NSLocationAlwaysAndWhenInUseUsageDescription` and request "Always" yourself once "While Using" is granted
(for example with [`permission_handler`](https://pub.dev/packages/permission_handler):
`Permission.locationAlways.request()`). The SDK does not request it.

> ⚠️ Do **not** add `bluetooth-central` to `UIBackgroundModes`. The SDK stops positioning in the
> background and does not use it; App Review can reject unused background modes (2.5.4).

### Android

Make `MainActivity` extend **`FlutterFragmentActivity`** — the SDK's permission request needs a
`ComponentActivity`, and the default `FlutterActivity` is not one:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

With the default `FlutterActivity`, `requestPermission()` throws `OneS1ghtException` with code
`unsupportedActivity`.

In `android/app/build.gradle.kts`:

```kotlin
android {
    compileSdk = 37
    defaultConfig {
        minSdk = 26
    }
}
```

The permissions (`RANGING`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `BLUETOOTH_SCAN`, `INTERNET`
…) are merged from the Android SDK's manifest. You do not add them yourself.

---

## Step 2: Initialize

```dart
await OneS1ght.initialize(sdkKey: 'ock_sdk_…');
```

Device support is not checked here, so that spaces and zones can be read on any device. To show a notice
first:

```dart
switch (await OneS1ght.deviceAvailability()) {
  case DeviceAvailability.available:
    break;
  case DeviceAvailability.osVersionTooLow:
    // "Update the OS"
  case DeviceAvailability.deviceNotSupported:
    // "This device does not support indoor positioning"
}
```

> Android: read `deviceAvailability()` **after** `initialize()`. Before that the Android SDK has no
> context to ask about the UWB chip and reports `deviceNotSupported` (with a `warn` log). iOS can answer
> at any time.

## Step 3: Permission

```dart
final status = await OneS1ght.requestPermission();   // shows the system dialog
```

`authorized` · `denied` (send the user to Settings) · `unsupported` (no dialog — the device cannot
position).

## Step 4: Profile

```dart
final profileId = await OneS1ght.createProfile({'ageGroup': '20s'});   // store it in your app
await OneS1ght.identify(profileId: profileId);   // required before begin()
```

## Step 5: Floor (optional)

```dart
final buildings = await OneS1ght.buildings();
final floors = await OneS1ght.floors(buildingId: buildings.first.id);
await OneS1ght.setFloorMap(floors.first, buildingId: buildings.first.id);
```

Without `setFloorMap` the engine finds the floor over BLE — follow it with `session.onFloorDetected`.
`floors()` leaves `image` empty. Call `floor(buildingId:, floorId:)` for the floor you draw.

## Step 6: Start positioning

```dart
final session = await OneS1ght.floorSession();
session.onZoneEnter.listen((zone) { ... });
session.onTriggers.listen((t) { ... });          // coupons and other actions for t.zoneId
session.onPosition.listen((c) { ... });          // floor-local metres
session.onStopped.listen((reason) { ... });      // engineFailed → fix the cause, then begin() again
session.onConfigChanged.listen((change) { ... });

await session.begin();
// ...
await session.end();
```

`pause()` / `resume()` stop only positions, upload and judgement; the engine keeps the floor, so resume
is immediate.

`onConfigChanged`: the SDK does nothing with it. On `ZonesChanged` / `ResyncNeeded`, call
`OneS1ght.refreshZones()` — debounce bursts (about 1 s), because every zone reload restarts the judgement.

---

## Errors

Every failure is a `OneS1ghtException`. `code` is the native SDK's error code and is the same on iOS
and Android:

| Code | Meaning |
|---|---|
| `E1001` | Not initialized |
| `E1002` | Invalid or revoked SDK key |
| `E1003` | Positioning disabled for this tenant |
| `E1004` | `identify(profileId:)` not called before `begin()` |
| `E2001` | OS version too low for positioning |
| `E2002` | Device does not support UWB positioning |
| `E3001` | No floor / building set (`setFloorMap` needs `buildingId` the first time) |
| `E5001` | Network failure |
| `unsupportedActivity` | Android — `MainActivity` is not a `FlutterFragmentActivity` |

`kind` is `sdk`, `api` or `plugin`. Server errors also carry `status` and `detail`.

Development logs: `OneS1ght.onDebugLog.listen(print);` — do not subscribe in production.

---

## API

| Dart | Notes |
|---|---|
| `OneS1ght.initialize(sdkKey:, baseUrl:)` · `reset()` | |
| `isInitialized()` · `deviceAvailability()` · `isDeviceAvailable()` · `googleMapKey()` | |
| `requestPermission()` · `setLanguage(code)` | |
| `buildings()` · `building(id:)` · `floors(buildingId:)` · `floor(buildingId:, floorId:)` | |
| `zones(...)` · `zone(...)` · `locators(...)` · `setFloorMap(floor, buildingId:)` · `refreshZones()` | |
| `createProfile` · `fetchProfile` · `replaceProfile` · `deleteProfile` · `identify(profileId:)` | |
| `uploadPendingPositions()` · `discardPendingPositions()` | |
| `floorSession()` → `FloorSession` | singleton |
| `FloorSession.begin` · `pause` · `resume` · `end` · `floor()` · `isRunning()` · `isPaused()` | |
| `FloorSession.onZoneEnter` · `onZoneExit` · `onZoneDwell` · `onPosition` · `onTriggers` · `onFloorDetected` · `onStopped` · `onConfigChanged` | `Stream`s |
| `OneS1ght.onDebugLog` | `Stream` |
| `OneS1ght.sdkVersion()` · `OneS1ght.pluginVersion` | native SDK / plugin version |

Not wrapped: custom positioning providers (`begin(provider:)`).

---

## Example

```sh
cd example
flutter run --dart-define=ONES1GHT_SDK_KEY=ock_sdk_…
```

Integration tests (no key needed; they check that calls reach the native SDK):

```sh
cd example
flutter test integration_test -d <device>
```
