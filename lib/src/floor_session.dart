//
//  floor_session.dart
//  측위 세션 — 측위를 켜고 끄고 이벤트를 받는다.
//
//  · **싱글턴** — UWB 라디오·판정 엔진·좌표 버퍼가 기기당 하나뿐이라 네이티브 SDK 도 세션이 하나다.
//    `OneS1ght.floorSession()` 은 항상 같은 인스턴스를 준다.
//  · 이벤트는 네이티브 콜백(iOS `onZoneEnter` 등)과 이름이 같은 Stream 이다. 여러 곳에서 들어도 된다.
//
import 'dart:async';

import 'channel.dart';
import 'models.dart';

class FloorSession {
  FloorSession._();

  static final FloorSession instance = FloorSession._();

  // MARK: - 이벤트

  /// 구역 진입 — 온디바이스 판정 즉시(서버 왕복 없음).
  Stream<Zone> get onZoneEnter => eventsNamed('zoneEnter').map((e) => Zone.fromMap(_map(e['zone'])));

  /// 구역 이탈.
  Stream<Zone> get onZoneExit => eventsNamed('zoneExit').map((e) => Zone.fromMap(_map(e['zone'])));

  /// 구역 체류 — `dwellSeconds` 도달 시 1회(반복 발화 없음).
  Stream<ZoneDwell> get onZoneDwell => eventsNamed(
    'zoneDwell',
  ).map((e) => ZoneDwell(Zone.fromMap(_map(e['zone'])), (e['seconds'] as num?)?.toDouble() ?? 0));

  /// 실시간 좌표(도면 로컬 미터) — 지도에 내 위치를 그린다.
  Stream<Coordinates> get onPosition => eventsNamed('position').map((e) => Coordinates.fromMap(_map(e['coordinates'])));

  /// 존 이벤트 서버 응답의 개인화 액션(쿠폰 등).
  Stream<ZoneTriggers> get onTriggers => eventsNamed(
    'triggers',
  ).map((e) => ZoneTriggers(e['zoneId'] as String? ?? '', decodeList(e['triggers'], Trigger.fromMap)));

  /// 엔진이 층을 잡았다(층 ID) / 잃었다(`null`). ID 는 `OneS1ght.floors()` 의 `Floor.id` 와 같다.
  Stream<String?> get onFloorDetected => eventsNamed('floorDetected').map((e) => e['floorId'] as String?);

  /// 측위 세션이 닫혔다. [StopReason.engineFailed] 면 원인(권한·Bluetooth 등)을 풀고 [begin] 으로 다시 연다.
  Stream<StopReason> get onStopped =>
      eventsNamed('stopped').map((e) => e['reason'] == 'engineFailed' ? StopReason.engineFailed : StopReason.ended);

  /// 콘솔에서 무언가 바뀌었다. SDK 는 이 신호로 아무것도 하지 않는다 — [ConfigChange] 참고.
  Stream<ConfigChange> get onConfigChanged =>
      eventsNamed('configChanged').map((e) => ConfigChange.fromMap(_map(e['change'])));

  // MARK: - 상태

  /// 이 세션이 보고 있는 층 — `setFloorMap` 이 정한 값. `null` 이면 층 미지정.
  Future<Floor?> floor() async {
    final m = await invoke<Map<Object?, Object?>>('session.floor');
    return m == null ? null : Floor.fromMap(m);
  }

  /// 측위 가동 중인가.
  Future<bool> isRunning() async => await invoke<bool>('session.isRunning') ?? false;

  /// 일시정지 중인가.
  Future<bool> isPaused() async => await invoke<bool>('session.isPaused') ?? false;

  // MARK: - 제어

  /// 측위 시작(매장 진입 시).
  ///
  /// 실패하면 [OneS1ghtException] — `E1001`(미초기화) · `E1004`(identify 안 함) · `E2001`(OS 낮음) ·
  /// `E2002`(기기 미지원).
  Future<void> begin() => invoke<void>('session.begin');

  /// 일시정지 — 좌표 표시·수집·판정만 멈추고 엔진은 계속 돌린다. [resume] 이 즉시 이어진다.
  Future<void> pause() => invoke<void>('session.pause');

  /// 일시정지 해제.
  Future<void> resume() => invoke<void>('session.resume');

  /// 측위 종료 + 잔여 좌표 전송. 초기화·층 설정은 유지 → [begin] 으로 재개.
  Future<void> end() => invoke<void>('session.end');
}

Map<Object?, Object?> _map(Object? v) => v is Map<Object?, Object?> ? v : const {};
