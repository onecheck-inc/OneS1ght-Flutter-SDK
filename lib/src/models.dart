//
//  models.dart
//  공개 모델 — iOS SDK 의 타입을 이름·필드 그대로 옮겼다(iOS 가 사양).
//
//  · 네이티브 ↔ Dart 는 StandardMessageCodec 의 Map 으로 오간다. 키 이름은 iOS 프로퍼티 이름과 같다.
//  · 읽을 때 관대하게 읽는다 — 빠진 숫자는 0, 빠진 문자열은 '' 로 둔다. 모델 하나가 깨져
//    목록 전체가 실패하면 이미 배포된 앱에서 화면이 통째로 빈다(네이티브 SDK 와 같은 원칙).
//

import 'package:flutter/foundation.dart';

/// 측위 가능 여부 — 사유 포함.
enum DeviceAvailability {
  /// 측위 가능.
  available,

  /// OS 가 낮다 — "OS 업데이트 후 사용 가능" 안내.
  osVersionTooLow,

  /// UWB 칩 미지원 기기.
  deviceNotSupported,
}

/// 측위 권한 요청 결과.
enum PermissionStatus {
  authorized,
  denied,

  /// 이 기기에서 측위가 불가하다 — 팝업 없이 돌아온다.
  unsupported,
}

/// SDK 로그 등급.
enum LogLevel { log, info, warn, error }

/// SDK 디버그 로그 한 줄 — `OneS1ght.onDebugLog` 로 온다.
@immutable
class DebugLog {
  const DebugLog(this.level, this.message);

  final LogLevel level;
  final String message;

  @override
  String toString() => '[${level.name}] $message';
}

@immutable
class Building {
  const Building({required this.id, required this.name, this.floorCount});

  final String id;
  final String name;
  final int? floorCount;

  factory Building.fromMap(Map<Object?, Object?> m) =>
      Building(id: _str(m['id']), name: _str(m['name']), floorCount: _intOrNull(m['floorCount']));

  @override
  bool operator ==(Object other) =>
      other is Building && other.id == id && other.name == name && other.floorCount == floorCount;

  @override
  int get hashCode => Object.hash(id, name, floorCount);

  @override
  String toString() => 'Building($id, $name)';
}

/// 층. 목록(`floors`)에서는 [image] 가 비어 있고, 단건(`floor`)으로 받으면 채워진다.
@immutable
class Floor {
  const Floor({
    required this.id,
    required this.name,
    this.image,
    this.hasPlan = false,
    this.originX = 0,
    this.originY = 0,
    this.widthM = 0,
    this.heightM = 0,
  });

  final String id;
  final String name;

  /// 도면 이미지(PNG 등 원본 바이트).
  final Uint8List? image;
  final bool hasPlan;

  /// 도면 좌하단 원점(미터).
  final double originX, originY;

  /// 도면 크기(미터).
  final double widthM, heightM;

  double get minX => originX;
  double get minY => originY;
  double get maxX => originX + widthM;
  double get maxY => originY + heightM;

  factory Floor.fromMap(Map<Object?, Object?> m) => Floor(
    id: _str(m['id']),
    name: _str(m['name']),
    image: m['image'] is Uint8List ? m['image'] as Uint8List : null,
    hasPlan: m['hasPlan'] == true,
    originX: _dbl(m['originX']),
    originY: _dbl(m['originY']),
    widthM: _dbl(m['widthM']),
    heightM: _dbl(m['heightM']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'image': image,
    'hasPlan': hasPlan,
    'originX': originX,
    'originY': originY,
    'widthM': widthM,
    'heightM': heightM,
  };

  @override
  bool operator ==(Object other) =>
      other is Floor &&
      other.id == id &&
      other.name == name &&
      other.hasPlan == hasPlan &&
      other.originX == originX &&
      other.originY == originY &&
      other.widthM == widthM &&
      other.heightM == heightM &&
      listEquals(other.image, image);

  @override
  int get hashCode => Object.hash(id, name, hasPlan, originX, originY, widthM, heightM);

  @override
  String toString() => 'Floor($id, $name)';
}

/// 도면 로컬 좌표(미터) 한 점 — 구역 꼭짓점.
@immutable
class Position {
  const Position(this.x, this.y);

  final double x, y;

  factory Position.fromMap(Map<Object?, Object?> m) => Position(_dbl(m['x']), _dbl(m['y']));

  @override
  bool operator ==(Object other) => other is Position && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Position($x, $y)';
}

/// 구역. 판정 파라미터는 콘솔이 정한 값이 그대로 온다(앱이 바꿀 수 없다).
@immutable
class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.polygon,
    required this.inDist,
    required this.inCount,
    required this.inCountInterval,
    required this.outPeriod,
    required this.priority,
    required this.callInout,
    this.dwellSeconds,
  });

  final String id;
  final String name;

  /// 꼭짓점 (순서대로).
  final List<Position> polygon;

  /// 진입 판단 거리(m).
  final double inDist;

  /// 진입 확정 감지 횟수.
  final int inCount;

  /// 감지 카운트 간격(초).
  final int inCountInterval;

  /// 이탈 판정 유예.
  final int outPeriod;

  /// 영역이 겹칠 때 우선순위.
  final int priority;

  /// 진출입 콜백 발행 여부.
  final bool callInout;

  /// 체류 판정 시간(초). 없으면 체류 이벤트가 나지 않는다.
  final int? dwellSeconds;

  factory Zone.fromMap(Map<Object?, Object?> m) => Zone(
    id: _str(m['id']),
    name: _str(m['name']),
    polygon: _list(m['polygon']).map(Position.fromMap).toList(growable: false),
    inDist: _dbl(m['inDist']),
    inCount: _int(m['inCount']),
    inCountInterval: _int(m['inCountInterval']),
    outPeriod: _int(m['outPeriod']),
    priority: _int(m['priority']),
    callInout: m['callInout'] == true,
    dwellSeconds: _intOrNull(m['dwellSeconds']),
  );

  @override
  bool operator ==(Object other) => other is Zone && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Zone($id, $name)';
}

@immutable
class Locator {
  const Locator({required this.address, required this.x, required this.y, required this.z, this.isPlaced = true});

  final int address;
  final double x, y, z;

  /// 도면에 배치됐는가 — 배치 안 된 로케이터는 좌표가 0 이다.
  final bool isPlaced;

  factory Locator.fromMap(Map<Object?, Object?> m) => Locator(
    address: _int(m['address']),
    x: _dbl(m['x']),
    y: _dbl(m['y']),
    z: _dbl(m['z']),
    isPlaced: m['isPlaced'] != false,
  );

  @override
  String toString() => 'Locator($address)';
}

/// 로케이터 + 세션 ID.
@immutable
class FloorLocators {
  const FloorLocators({required this.locators, this.sessionId});

  final List<Locator> locators;
  final int? sessionId;

  bool get positioningReady => locators.isNotEmpty && sessionId != null;

  factory FloorLocators.fromMap(Map<Object?, Object?> m) => FloorLocators(
    locators: _list(m['locators']).map(Locator.fromMap).toList(growable: false),
    sessionId: _intOrNull(m['sessionId']),
  );
}

/// 실시간 좌표(도면 로컬 미터).
@immutable
class Coordinates {
  const Coordinates(this.x, this.y, this.z);

  final double x, y, z;

  factory Coordinates.fromMap(Map<Object?, Object?> m) => Coordinates(_dbl(m['x']), _dbl(m['y']), _dbl(m['z']));

  @override
  bool operator ==(Object other) => other is Coordinates && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Coordinates($x, $y, $z)';
}

/// 존 이벤트 서버 응답의 개인화 액션.
@immutable
class Trigger {
  const Trigger({required this.triggerId, required this.type, this.payload});

  final String triggerId;

  /// `signage` · `coupon` · `tracking` · `merch` · `generic`.
  /// ⚠️ 문자열이다 — 서버가 종류를 늘릴 수 있어 모르는 값도 그대로 온다.
  final String type;

  /// 액션 내용(title·rule 등). 값은 문자열로 접혀 온다.
  final Map<String, String>? payload;

  factory Trigger.fromMap(Map<Object?, Object?> m) => Trigger(
    triggerId: _str(m['triggerId']),
    type: m['type'] is String ? m['type'] as String : 'generic',
    payload: m['payload'] is Map ? _stringMap(m['payload']) : null,
  );

  @override
  String toString() => 'Trigger($triggerId, $type)';
}

/// `onTriggers` 한 건 — (zoneId, triggers).
@immutable
class ZoneTriggers {
  const ZoneTriggers(this.zoneId, this.triggers);

  final String zoneId;
  final List<Trigger> triggers;
}

/// `onZoneDwell` 한 건 — 체류 시간(초)에 도달했다.
@immutable
class ZoneDwell {
  const ZoneDwell(this.zone, this.seconds);

  final Zone zone;
  final double seconds;
}

/// 측위 세션이 닫힌 이유.
///
/// ⚠️ 새 이유가 늘 수 있다 — `switch` 에는 `default` 를 둘 것.
enum StopReason {
  /// 앱이 `end()` 를 불렀다(또는 `reset()`·키 교체).
  ended,

  /// 엔진이 스스로 꺼졌고 다시 켜지지 않아 SDK 가 세션을 닫았다.
  engineFailed,
}

/// 콘솔에서 무언가 바뀌었다. **SDK 는 이 신호로 아무것도 하지 않는다** — 무엇을 다시 받을지는 앱이 정한다.
///
/// ⚠️ 새 종류가 늘 수 있다 — `switch` 에는 `default` 를 둘 것.
sealed class ConfigChange {
  const ConfigChange();

  factory ConfigChange.fromMap(Map<Object?, Object?> m) {
    switch (m['type']) {
      case 'zonesChanged':
        return ZonesChanged(m['floorId'] as String?);
      case 'planChanged':
        return PlanChanged(m['floorId'] as String?);
      case 'rulesChanged':
        return RulesChanged(m['zoneId'] as String?);
      case 'sdkConfigChanged':
        return SdkConfigChanged(rateHz: _intOrNull(m['rateHz']), logLevel: m['logLevel'] as String?);
      default:
        // 모르는 종류는 "다시 맞춰라" 로 받는다 — 놓치는 것보다 한 번 더 받는 편이 안전하다.
        return const ResyncNeeded();
    }
  }
}

/// 구역이 바뀌었다 → `OneS1ght.refreshZones()`. ⚠️ 연속해서 오면 접어라(권장 1초).
class ZonesChanged extends ConfigChange {
  const ZonesChanged(this.floorId);
  final String? floorId;
}

/// 도면이 바뀌었다 → 층 단건을 다시 받아 지도를 다시 그린다.
class PlanChanged extends ConfigChange {
  const PlanChanged(this.floorId);
  final String? floorId;
}

/// 시책이 바뀌었다 → 지금 들어가 있는 구역이 있으면 그 구역의 이벤트를 한 번 다시 조회한다.
class RulesChanged extends ConfigChange {
  const RulesChanged(this.zoneId);
  final String? zoneId;
}

/// SDK 설정(수집 Hz·로그 등급)이 바뀌었다.
class SdkConfigChanged extends ConfigChange {
  const SdkConfigChanged({this.rateHz, this.logLevel});
  final int? rateHz;
  final String? logLevel;
}

/// 실시간 연결이 끊겼다 다시 붙었다 — 놓친 변경이 있을 수 있다. 구역을 다시 받는다.
class ResyncNeeded extends ConfigChange {
  const ResyncNeeded();
}

// MARK: - 관대한 읽기

String _str(Object? v) => v is String ? v : (v?.toString() ?? '');

double _dbl(Object? v) => v is num ? v.toDouble() : 0;

int _int(Object? v) => v is num ? v.toInt() : 0;

int? _intOrNull(Object? v) => v is num ? v.toInt() : null;

Iterable<Map<Object?, Object?>> _list(Object? v) =>
    v is List ? v.whereType<Map<Object?, Object?>>() : const <Map<Object?, Object?>>[];

Map<String, String> _stringMap(Object? v) {
  if (v is! Map) return const {};
  return {
    for (final e in v.entries)
      if (e.key != null) e.key.toString(): e.value?.toString() ?? '',
  };
}

/// 내부 — 채널 응답을 Map 목록으로 읽는다.
List<T> decodeList<T>(Object? v, T Function(Map<Object?, Object?>) f) => _list(v).map(f).toList(growable: false);

/// 내부 — 채널 응답을 문자열 Map 으로 읽는다.
Map<String, String> decodeStringMap(Object? v) => _stringMap(v);
