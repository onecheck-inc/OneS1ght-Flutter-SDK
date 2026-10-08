//
//  ones1ght.dart
//  공개 진입점 — 앱이 보는 유일한 문. 전부 static 이다(네이티브 SDK 와 같다).
//
//  이 플러그인은 OneS1ght iOS·Android SDK 를 감싸기만 한다. 판정·전송·재시도는 네이티브 SDK 가 하고,
//  여기는 호출을 넘기고 결과를 Dart 타입으로 바꾼다. 앱이 백그라운드로 가 Dart 가 멈춰도 네이티브 쪽
//  동작은 그대로다.
//
//  사용:
//    await OneS1ght.initialize(sdkKey: 'ock_…');
//    OneS1ght.identify(profileId: 'pf_8a3c');
//    final session = await OneS1ght.floorSession();
//    session.onTriggers.listen((t) { ... });
//    await session.begin();
//
import 'dart:async';

import 'channel.dart';
import 'errors.dart';
import 'floor_session.dart';
import 'models.dart';

abstract final class OneS1ght {
  /// 이 Flutter 플러그인의 버전. 네이티브 SDK 버전은 [sdkVersion].
  static const String pluginVersion = '0.0.3';

  /// 아래에 붙은 네이티브 SDK 의 버전(서버 로그의 sdk_version 에 실린다).
  static Future<String> sdkVersion() async => await invoke<String>('sdkVersion') ?? '';

  // MARK: - 로그

  /// SDK 내부 활동 로그(디버그용). 운영에선 구독하지 않기를 권한다.
  static Stream<DebugLog> get onDebugLog => eventsNamed('debugLog').map(
    (e) => DebugLog(
      LogLevel.values.firstWhere((l) => l.name == e['level'], orElse: () => LogLevel.log),
      e['message'] as String? ?? '',
    ),
  );

  // MARK: - 상태

  /// 초기화 성공 여부(키 유효 + 설정 로드됨). 기기 지원 여부는 별개 — [deviceAvailability].
  static Future<bool> isInitialized() async => await invoke<bool>('isInitialized') ?? false;

  /// 이 기기에서 측위가 가능한가 + 불가 사유. initialize 전에도 부를 수 있다.
  static Future<DeviceAvailability> deviceAvailability() async {
    final raw = await invoke<String>('deviceAvailability');
    return DeviceAvailability.values.firstWhere(
      (v) => v.name == raw,
      orElse: () => DeviceAvailability.deviceNotSupported,
    );
  }

  /// [deviceAvailability] 의 요약형.
  static Future<bool> isDeviceAvailable() async => await deviceAvailability() == DeviceAvailability.available;

  /// 콘솔이 내려준 Google Maps 키 — 앱이 자체 지도를 그릴 때 쓴다. initialize 성공 전에는 `null`.
  static Future<String?> googleMapKey() => invoke<String>('googleMapKey');

  // MARK: - 권한

  /// 측위 권한 확인. **호출하면 시스템 팝업이 뜬다** — 확인과 요청이 분리되지 않는다.
  /// 이미 답한 권한이면 팝업 없이 즉시 돌아온다. initialize 전에도 부를 수 있다.
  ///
  /// Android 는 앱의 Activity 가 `FlutterFragmentActivity` 여야 한다(README 참고) — 아니면
  /// [OneS1ghtException.unsupportedActivity].
  static Future<PermissionStatus> requestPermission() async {
    final raw = await invoke<String>('requestPermission');
    return PermissionStatus.values.firstWhere((v) => v.name == raw, orElse: () => PermissionStatus.denied);
  }

  /// SDK 로그·안내 문구 언어 — `'ko'` · `'ja'` · `'en'`. `null` 이면 기기 언어(기본값).
  static Future<void> setLanguage(String? code) => invoke<void>('setLanguage', {'code': code});

  // MARK: - 생명주기

  /// 초기화(앱 시작 시 1회) — 키 검증 + 테넌트 설정 수신. 기기 지원 여부는 여기서 보지 않는다.
  ///
  /// 실패 시 재호출 = 재시도 · 성공 후 재호출 = 무시 · 다른 키로 재호출 = 세션 재구성.
  /// - [sdkKey]: OneS1ght 콘솔 발급 키(`ock_…`). 측위에 필요한 나머지 키는 SDK 가 콘솔에서 받는다.
  /// - [baseUrl]: 자체 서버를 구축한 고객만.
  static Future<void> initialize({required String sdkKey, String? baseUrl}) =>
      invoke<void>('initialize', {'sdkKey': sdkKey, 'baseUrl': baseUrl});

  /// 초기화 리셋 — 세션을 버린다. 이후 다른 키로 [initialize] 할 수 있다.
  static Future<void> reset() => invoke<void>('reset');

  // MARK: - 공간 조회

  /// 건물 목록. ⚠️ 빈 목록은 측위 키를 콘솔에서 못 받았을 때도 온다 — [onDebugLog] 의 E1007 로 구분한다.
  static Future<List<Building>> buildings() async => decodeList(await invoke<Object>('buildings'), Building.fromMap);

  /// 건물 단건.
  static Future<Building> building({required String id}) async =>
      Building.fromMap(await _requireMap('building', {'id': id}));

  /// 층 목록 — 도면 이미지는 비어 있다(목록 경량화). 지도를 그릴 층만 [floor] 로 받는다.
  static Future<List<Floor>> floors({required String buildingId}) async =>
      decodeList(await invoke<Object>('floors', {'buildingId': buildingId}), Floor.fromMap);

  /// 층 단건 — 도면 이미지 포함.
  static Future<Floor> floor({required String buildingId, required String floorId}) async =>
      Floor.fromMap(await _requireMap('floor', {'buildingId': buildingId, 'floorId': floorId}));

  /// 존 목록.
  static Future<List<Zone>> zones({required String buildingId, required String floorId}) async =>
      decodeList(await invoke<Object>('zones', {'buildingId': buildingId, 'floorId': floorId}), Zone.fromMap);

  /// 존 단건.
  static Future<Zone> zone({required String buildingId, required String floorId, required String zoneId}) async =>
      Zone.fromMap(await _requireMap('zone', {'buildingId': buildingId, 'floorId': floorId, 'zoneId': zoneId}));

  /// 로케이터 + 세션 ID.
  static Future<FloorLocators> locators({required String buildingId, required String floorId}) async =>
      FloorLocators.fromMap(await _requireMap('locators', {'buildingId': buildingId, 'floorId': floorId}));

  // MARK: - 층 지정

  /// 측위·판정에 쓸 층을 지정한다. `null` 이면 비운다. 가동 중이면 즉시 층 전환.
  /// [buildingId] 를 생략하면 직전에 지정한 건물을 쓴다 — 처음에는 함께 넘긴다(아니면 E3001).
  static Future<void> setFloorMap(Floor? floor, {String? buildingId}) =>
      invoke<void>('setFloorMap', {'floor': floor?.toMap(), 'buildingId': buildingId});

  /// 현재 층의 존만 재조회(도면 재다운로드 없음). 바뀌었으면 판정 엔진에도 즉시 반영된다.
  static Future<List<Zone>> refreshZones() async => decodeList(await invoke<Object>('refreshZones'), Zone.fromMap);

  // MARK: - 측위 세션

  /// 측위 세션(싱글턴). initialize 를 한 번도 안 불렀으면 E1001.
  static Future<FloorSession> floorSession() async {
    await invoke<void>('floorSession');
    return FloorSession.instance;
  }

  // MARK: - 프로필

  /// 프로필 생성 — 서버가 발급한 profileId 를 돌려준다. **앱이 보관해 재사용해야 한다.**
  /// ⚠️ 나이는 정확값 대신 연령대("20s")로 넣기를 권한다.
  static Future<String> createProfile(Map<String, String> attributes) async =>
      await invoke<String>('createProfile', {'attributes': attributes}) ?? '';

  /// 프로필 속성 조회.
  static Future<Map<String, String>> fetchProfile(String profileId) async =>
      decodeStringMap(await invoke<Object>('fetchProfile', {'profileId': profileId}));

  /// 프로필 속성 **전체 교체** — 넘기지 않은 속성은 지워진다.
  static Future<void> replaceProfile(String profileId, {required Map<String, String> attributes}) =>
      invoke<void>('replaceProfile', {'profileId': profileId, 'attributes': attributes});

  /// 프로필 삭제.
  static Future<void> deleteProfile(String profileId) => invoke<void>('deleteProfile', {'profileId': profileId});

  // MARK: - 좌표 버퍼

  /// 쌓인 좌표를 지금 서버로 보낸다.
  static Future<void> uploadPendingPositions() => invoke<void>('uploadPendingPositions');

  /// 쌓인 좌표를 **보내지 않고 버린다**.
  static Future<void> discardPendingPositions() => invoke<void>('discardPendingPositions');

  // MARK: - 사용자

  /// 프로필 연결 — 좌표·존 이벤트가 이 ID 로 귀속된다. 로그아웃 등 해제는 `null`.
  /// `begin()` 전에 반드시 불러야 한다(없으면 E1004).
  static Future<void> identify({required String? profileId}) => invoke<void>('identify', {'profileId': profileId});

  static Future<Map<Object?, Object?>> _requireMap(String method, Map<String, Object?> args) async {
    final m = await invoke<Map<Object?, Object?>>(method, args);
    if (m == null) {
      throw OneS1ghtException(code: OneS1ghtException.internal, message: '$method returned nothing', kind: 'plugin');
    }
    return m;
  }
}
