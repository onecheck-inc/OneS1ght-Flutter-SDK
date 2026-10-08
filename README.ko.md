# OneS1ght SDK — Flutter (미리보기)

[English](README.md) | **한국어**

> ⚠️ **미리보기입니다.** 1.0 전까지 API 가 바뀔 수 있습니다. 정식 지원 SDK 는 네이티브
> [iOS](https://github.com/onecheck-inc/OneS1ght-iOS-SDK) ·
> [Android](https://github.com/onecheck-inc/OneS1ght-Android-SDK) SDK 입니다.

Flutter 앱용 실내 위치 인텔리전스 SDK 입니다. OneS1ght iOS·Android SDK 를 얇게 감쌉니다 — 측위, 구역
진입·이탈·체류 판정, 전송·재시도는 전부 네이티브 SDK 가 하고, Dart 는 호출을 넘기고 결과를 Dart 타입으로
바꾸기만 합니다. 그래서 앱이 백그라운드로 가 Dart 가 멈춰도 SDK 동작은 네이티브 앱과 같습니다.

Dart API 이름은 iOS SDK 를 따릅니다. 네이티브 콜백(`onZoneEnter`, `onPosition` …)은 같은 이름의 Dart
`Stream` 입니다.

---

## 요구사항

| 항목 | 요구사항 |
|---|---|
| Flutter | **3.44+** (Swift Package Manager 켜짐 — 3.44 부터 기본값) |
| iOS | 패키지: iOS 18.0+ · 측위: **iOS 27.0+**, UWB 칩이 있는 iPhone |
| Android | 패키지: `minSdk 26` · `compileSdk 37` · 측위: **Android 17 (API 37)+**, UWB DL-TDoA 지원 기기 |
| 네이티브 SDK (고정) | iOS `0.2.2` · Android `0.0.9` |

측위가 안 되는 기기에서도 앱은 정상 동작하고 측위만 꺼져 있습니다.

SDK 키(`ock_sdk_…`, OneS1ght 콘솔 → **모바일 SDK**)와, 고객사에 건물·층·로케이터·구역이 준비되어 있어야
합니다.

---

## Step 1: 플러그인 추가

```sh
flutter pub add ones1ght_sdk
```

또는 `pubspec.yaml` 에:

```yaml
dependencies:
  ones1ght_sdk: ^0.0.2
```

```dart
import 'package:ones1ght_sdk/ones1ght_sdk.dart';
```

> 0.0.1 의 경로 `package:ones1ght_sdk/ones1ght.dart` 도 그대로 동작합니다.

### iOS

**Swift Package Manager 로만 붙습니다.** CocoaPods 는 지원하지 않습니다 — 측위 엔진이 동적 프레임워크라
CocoaPods 로는 앱에 실리지 않고, 앱이 실행 즉시 종료됩니다. Swift Package Manager 가 꺼져 있으면
`pod install` 이 아래 명령을 안내하며 멈춥니다:

```sh
flutter config --enable-swift-package-manager
```

iOS 배포 타깃을 **18.0** 으로 올립니다(`ios/Runner.xcodeproj` → `IPHONEOS_DEPLOYMENT_TARGET`).

`ios/Runner/Info.plist` 에 아래를 넣습니다. 앞의 세 개가 없으면 권한을 요청하는 순간 앱이 종료됩니다:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>매장 내 위치를 파악하는 데 사용합니다.</string>
<key>NSNearbyInteractionUsageDescription</key>
<string>UWB 정밀 측위에 사용합니다.</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>주변 측위 장비를 찾는 데 사용합니다.</string>
<key>NSLocationTemporaryUsageDescriptionDictionary</key>
<dict>
    <key>Positioning</key>
    <string>정확한 실내 위치를 계산하는 데 사용합니다.</string>
</dict>
```

> ⚠️ `NSLocationTemporaryUsageDescriptionDictionary` 안의 키는 **`Positioning`** 이어야 합니다.
> 다르면 iOS 가 요청을 오류도 로그도 없이 무시합니다.

**iOS 27.2 이상: 위치 권한이 '항상' 이어야 합니다.** 엔진은 BLE 비콘 영역 감시로 층을 찾는데, iOS 27.2
부터 '앱 사용 중' 권한에서는 시스템이 계속 "밖" 으로 알립니다. `NSLocationAlwaysAndWhenInUseUsageDescription`
을 넣고, '앱 사용 중' 허용 뒤 앱이 직접 '항상' 을 요청하세요(예: [`permission_handler`](https://pub.dev/packages/permission_handler)
의 `Permission.locationAlways.request()`). SDK 는 '항상' 을 요청하지 않습니다.

> ⚠️ `UIBackgroundModes` 에 `bluetooth-central` 은 넣지 마세요. SDK 는 백그라운드에서 측위를 멈춰 이 모드를
> 쓰지 않고, App Store 심사에서 쓰지 않는 백그라운드 모드(2.5.4)로 거절될 수 있습니다.

### Android

`MainActivity` 를 **`FlutterFragmentActivity`** 로 바꿉니다 — SDK 의 권한 요청에는 `ComponentActivity` 가
필요한데, 기본 `FlutterActivity` 는 그렇지 않습니다:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

기본 `FlutterActivity` 그대로면 `requestPermission()` 이 코드 `unsupportedActivity` 의 `OneS1ghtException`
을 던집니다.

`android/app/build.gradle.kts`:

```kotlin
android {
    compileSdk = 37
    defaultConfig {
        minSdk = 26
    }
}
```

권한(`RANGING`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `BLUETOOTH_SCAN`, `INTERNET` …)은
Android SDK 매니페스트에서 병합됩니다. 따로 넣지 않습니다.

---

## Step 2: 초기화

```dart
await OneS1ght.initialize(sdkKey: 'ock_sdk_…');
```

기기 지원 여부는 여기서 보지 않습니다 — 어떤 기기에서든 공간·구역 조회는 열려 있어야 하기 때문입니다.
안내를 먼저 띄우려면:

```dart
switch (await OneS1ght.deviceAvailability()) {
  case DeviceAvailability.available:
    break;
  case DeviceAvailability.osVersionTooLow:
    // "OS 업데이트 후 사용 가능"
  case DeviceAvailability.deviceNotSupported:
    // "이 기기는 실내 측위를 지원하지 않습니다"
}
```

> Android: `deviceAvailability()` 는 **`initialize()` 다음에** 읽습니다. 그 전에는 Android SDK 가 UWB 칩을
> 물어볼 Context 가 없어 `deviceNotSupported` 를 돌려주고 `warn` 로그를 남깁니다. iOS 는 언제든 됩니다.

## Step 3: 권한

```dart
final status = await OneS1ght.requestPermission();   // 시스템 창이 뜹니다
```

`authorized` · `denied`(설정 앱으로 안내) · `unsupported`(창 없이 돌아옴 — 측위 불가 기기).

## Step 4: 프로필

```dart
final profileId = await OneS1ght.createProfile({'ageGroup': '20s'});   // 앱이 보관합니다
await OneS1ght.identify(profileId: profileId);   // begin() 전에 필수
```

## Step 5: 층 지정 (선택)

```dart
final buildings = await OneS1ght.buildings();
final floors = await OneS1ght.floors(buildingId: buildings.first.id);
await OneS1ght.setFloorMap(floors.first, buildingId: buildings.first.id);
```

`setFloorMap` 을 안 하면 엔진이 BLE 로 층을 찾습니다 — `session.onFloorDetected` 로 따라갑니다.
`floors()` 는 `image` 가 비어 있습니다. 지도를 그릴 층만 `floor(buildingId:, floorId:)` 로 받으세요.

## Step 6: 측위 시작

```dart
final session = await OneS1ght.floorSession();
session.onZoneEnter.listen((zone) { ... });
session.onTriggers.listen((t) { ... });          // t.zoneId 의 쿠폰 등 액션
session.onPosition.listen((c) { ... });          // 도면 로컬 미터
session.onStopped.listen((reason) { ... });      // engineFailed → 원인을 풀고 begin() 다시
session.onConfigChanged.listen((change) { ... });

await session.begin();
// ...
await session.end();
```

`pause()` / `resume()` 는 좌표·전송·판정만 멈춥니다. 엔진은 층을 계속 잡고 있어 재개가 즉시 이어집니다.

`onConfigChanged`: SDK 는 이 신호로 아무것도 하지 않습니다. `ZonesChanged` / `ResyncNeeded` 가 오면
`OneS1ght.refreshZones()` 를 부르세요 — 구역을 다시 물릴 때마다 판정이 처음부터 시작되므로, 연달아 오면
접으세요(1초 정도).

---

## 오류

실패는 모두 `OneS1ghtException` 입니다. `code` 는 네이티브 SDK 의 오류 코드이고 iOS·Android 가 같습니다:

| 코드 | 뜻 |
|---|---|
| `E1001` | 초기화 안 됨 |
| `E1002` | SDK 키 무효·폐기 |
| `E1003` | 이 고객사에서 측위가 꺼져 있음 |
| `E1004` | `begin()` 전에 `identify(profileId:)` 를 안 부름 |
| `E2001` | 측위하기엔 OS 가 낮음 |
| `E2002` | UWB 측위 미지원 기기 |
| `E3001` | 층·건물 미지정(`setFloorMap` 은 처음에 `buildingId` 가 필요) |
| `E5001` | 네트워크 실패 |
| `unsupportedActivity` | Android — `MainActivity` 가 `FlutterFragmentActivity` 가 아님 |

`kind` 는 `sdk` · `api` · `plugin` 입니다. 서버 오류는 `status`·`detail` 도 함께 옵니다.

개발 중 로그: `OneS1ght.onDebugLog.listen(print);` — 운영에서는 구독하지 마세요.

---

## API

| Dart | 비고 |
|---|---|
| `OneS1ght.initialize(sdkKey:, baseUrl:)` · `reset()` | |
| `isInitialized()` · `deviceAvailability()` · `isDeviceAvailable()` · `googleMapKey()` | |
| `requestPermission()` · `setLanguage(code)` | |
| `buildings()` · `building(id:)` · `floors(buildingId:)` · `floor(buildingId:, floorId:)` | |
| `zones(...)` · `zone(...)` · `locators(...)` · `setFloorMap(floor, buildingId:)` · `refreshZones()` | |
| `createProfile` · `fetchProfile` · `replaceProfile` · `deleteProfile` · `identify(profileId:)` | |
| `uploadPendingPositions()` · `discardPendingPositions()` | |
| `floorSession()` → `FloorSession` | 싱글턴 |
| `FloorSession.begin` · `pause` · `resume` · `end` · `floor()` · `isRunning()` · `isPaused()` | |
| `FloorSession.onZoneEnter` · `onZoneExit` · `onZoneDwell` · `onPosition` · `onTriggers` · `onFloorDetected` · `onStopped` · `onConfigChanged` | `Stream` |
| `OneS1ght.onDebugLog` | `Stream` |
| `OneS1ght.sdkVersion()` · `OneS1ght.pluginVersion` | 네이티브 SDK / 플러그인 버전 |

감싸지 않은 것: 커스텀 측위 provider(`begin(provider:)`).

---

## 예제

```sh
cd example
flutter run --dart-define=ONES1GHT_SDK_KEY=ock_sdk_…
```

통합 테스트(키 없이 돌아갑니다 — 호출이 네이티브 SDK 까지 닿는지 확인):

```sh
cd example
flutter test integration_test -d <기기>
```
