import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ones1ght_sdk/ones1ght.dart';

// 네이티브 플러그인을 흉내 낸다 — 채널 계약(메서드 이름·인자·응답 모양·오류 코드)을 Dart 쪽에서 고정한다.
// 네이티브 쪽은 example 앱을 시뮬레이터·에뮬레이터에서 돌려 확인한다(README).

const _methods = MethodChannel('ones1ght');
const _events = 'ones1ght/events';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Object? Function(MethodCall) reply;

  setUp(() {
    calls = [];
    reply = (_) => null;
    messenger.setMockMethodCallHandler(_methods, (call) async {
      calls.add(call);
      final r = reply(call);
      if (r is PlatformException) throw r;
      return r;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_methods, null);
    messenger.setMockStreamHandler(const EventChannel(_events), null);
  });

  group('호출', () {
    test('initialize 는 키와 baseUrl 을 그대로 넘긴다', () async {
      await OneS1ght.initialize(sdkKey: 'ock_test', baseUrl: 'https://example.com/api');
      expect(calls.single.method, 'initialize');
      expect(calls.single.arguments, {'sdkKey': 'ock_test', 'baseUrl': 'https://example.com/api'});
    });

    test('deviceAvailability 는 이름으로 읽고, 모르는 값은 미지원으로 본다', () async {
      reply = (_) => 'osVersionTooLow';
      expect(await OneS1ght.deviceAvailability(), DeviceAvailability.osVersionTooLow);
      expect(await OneS1ght.isDeviceAvailable(), isFalse);
      reply = (_) => 'somethingNew';
      expect(await OneS1ght.deviceAvailability(), DeviceAvailability.deviceNotSupported);
    });

    test('requestPermission 은 모르는 값을 거부로 본다', () async {
      reply = (_) => 'authorized';
      expect(await OneS1ght.requestPermission(), PermissionStatus.authorized);
      reply = (_) => null;
      expect(await OneS1ght.requestPermission(), PermissionStatus.denied);
    });

    test('floors 는 목록을 읽고 깨진 항목만 건너뛴다', () async {
      reply = (_) => [
        {'id': 'f1', 'name': '1F', 'hasPlan': true, 'originX': 1, 'widthM': 20.5, 'heightM': 10},
        'not a map',
        {'id': 'f2', 'name': '2F'},
      ];
      final floors = await OneS1ght.floors(buildingId: 'b1');
      expect(calls.single.arguments, {'buildingId': 'b1'});
      expect(floors.map((f) => f.id), ['f1', 'f2']);
      expect(floors.first.hasPlan, isTrue);
      expect(floors.first.originX, 1.0);
      expect(floors.first.maxX, 21.5);
      expect(floors.last.image, isNull);
      expect(floors.last.widthM, 0);
    });

    test('setFloorMap 은 층을 통째로 돌려보낸다(도면 이미지 포함)', () async {
      final image = Uint8List.fromList([1, 2, 3]);
      final floor = Floor(id: 'f1', name: '1F', image: image, hasPlan: true, widthM: 3);
      await OneS1ght.setFloorMap(floor, buildingId: 'b1');
      final args = calls.single.arguments as Map;
      expect(args['buildingId'], 'b1');
      expect((args['floor'] as Map)['id'], 'f1');
      expect((args['floor'] as Map)['image'], image);
      expect(Floor.fromMap((args['floor'] as Map).cast()), floor);
    });

    test('setFloorMap(null) 은 층을 비운다', () async {
      await OneS1ght.setFloorMap(null);
      expect(calls.single.arguments, {'floor': null, 'buildingId': null});
    });

    test('zones 는 꼭짓점·판정 값을 읽는다', () async {
      reply = (_) => [
        {
          'id': 'z1',
          'name': 'A',
          'polygon': [
            {'x': 0, 'y': 0},
            {'x': 1.5, 'y': 2},
          ],
          'inDist': 3.0,
          'inCount': 2,
          'inCountInterval': 1,
          'outPeriod': 5,
          'priority': 1,
          'callInout': true,
          'dwellSeconds': null,
        },
      ];
      final z = (await OneS1ght.zones(buildingId: 'b', floorId: 'f')).single;
      expect(z.polygon, [const Position(0, 0), const Position(1.5, 2)]);
      expect(z.inDist, 3.0);
      expect(z.callInout, isTrue);
      expect(z.dwellSeconds, isNull);
    });

    test('locators 는 세션 ID 가 있어야 측위 준비 완료다', () async {
      reply = (_) => {
        'locators': [
          {'address': 7, 'x': 1, 'y': 2, 'z': 3, 'isPlaced': true},
        ],
        'sessionId': null,
      };
      final l = await OneS1ght.locators(buildingId: 'b', floorId: 'f');
      expect(l.locators.single.address, 7);
      expect(l.positioningReady, isFalse);
    });

    test('프로필 속성은 문자열 Map 으로 오간다', () async {
      reply = (c) => c.method == 'createProfile' ? 'pf_1' : {'age': '20s', 'n': 3};
      expect(await OneS1ght.createProfile({'age': '20s'}), 'pf_1');
      expect(calls.single.arguments, {
        'attributes': {'age': '20s'},
      });
      expect(await OneS1ght.fetchProfile('pf_1'), {'age': '20s', 'n': '3'});
    });

    test('floorSession 은 항상 같은 인스턴스다', () async {
      final a = await OneS1ght.floorSession();
      final b = await OneS1ght.floorSession();
      expect(identical(a, b), isTrue);
      expect(calls.map((c) => c.method), ['floorSession', 'floorSession']);
    });

    test('세션 제어는 session.* 로 간다', () async {
      final s = await OneS1ght.floorSession();
      await s.begin();
      await s.pause();
      await s.resume();
      await s.end();
      expect(calls.skip(1).map((c) => c.method), ['session.begin', 'session.pause', 'session.resume', 'session.end']);
    });
  });

  group('오류', () {
    test('SDK 오류는 E-코드와 세부 정보를 그대로 싣는다', () async {
      reply = (_) => PlatformException(
        code: 'E5002',
        message: '서버 오류 (HTTP 503)',
        details: {'kind': 'api', 'name': 'server', 'status': 503, 'detail': 'maintenance'},
      );
      try {
        await OneS1ght.buildings();
        fail('던져야 한다');
      } on OneS1ghtException catch (e) {
        expect(e.code, 'E5002');
        expect(e.kind, 'api');
        expect(e.name, 'server');
        expect(e.status, 503);
        expect(e.detail, 'maintenance');
      }
    });

    test('세부 정보가 없어도 코드는 남는다', () async {
      reply = (c) => c.method == 'session.begin' ? PlatformException(code: 'E1001') : null;
      await expectLater(
        (await OneS1ght.floorSession()).begin(),
        throwsA(
          isA<OneS1ghtException>().having((e) => e.code, 'code', 'E1001').having((e) => e.message, 'message', 'E1001'),
        ),
      );
    });
  });

  group('이벤트', () {
    late StreamController<Object?> native;

    setUp(() {
      native = StreamController<Object?>();
      messenger.setMockStreamHandler(
        const EventChannel(_events),
        MockStreamHandler.inline(
          onListen: (args, sink) {
            native.stream.listen(sink.success);
          },
        ),
      );
    });

    test('이벤트는 이름으로 갈라져 각 스트림에 간다', () async {
      final s = await OneS1ght.floorSession();
      final enters = <Zone>[];
      final positions = <Coordinates>[];
      final floors = <String?>[];
      final subs = [
        s.onZoneEnter.listen(enters.add),
        s.onPosition.listen(positions.add),
        s.onFloorDetected.listen(floors.add),
      ];
      await pumpEventQueue();

      native.add({
        'event': 'zoneEnter',
        'zone': {'id': 'z1', 'name': 'A', 'polygon': []},
      });
      native.add({
        'event': 'position',
        'coordinates': {'x': 1, 'y': 2.5, 'z': 0},
      });
      native.add({'event': 'floorDetected', 'floorId': null});
      native.add({'event': 'unknownEvent'});
      await pumpEventQueue();

      expect(enters.single.id, 'z1');
      expect(positions.single, const Coordinates(1, 2.5, 0));
      expect(floors, [null]);
      for (final sub in subs) {
        await sub.cancel();
      }
    });

    test('트리거·체류·종료·콘솔 변경을 읽는다', () async {
      final s = await OneS1ght.floorSession();
      final triggers = <ZoneTriggers>[];
      final dwells = <ZoneDwell>[];
      final stops = <StopReason>[];
      final changes = <ConfigChange>[];
      final subs = [
        s.onTriggers.listen(triggers.add),
        s.onZoneDwell.listen(dwells.add),
        s.onStopped.listen(stops.add),
        s.onConfigChanged.listen(changes.add),
      ];
      await pumpEventQueue();

      native.add({
        'event': 'triggers',
        'zoneId': 'z1',
        'triggers': [
          {
            'triggerId': 't1',
            'type': 'coupon',
            'payload': {'title': '10%'},
          },
          {'triggerId': 't2'},
        ],
      });
      native.add({
        'event': 'zoneDwell',
        'zone': {'id': 'z1', 'name': 'A'},
        'seconds': 30,
      });
      native.add({'event': 'stopped', 'reason': 'engineFailed'});
      native.add({
        'event': 'configChanged',
        'change': {'type': 'rulesChanged', 'zoneId': 'z1'},
      });
      native.add({
        'event': 'configChanged',
        'change': {'type': 'sdkConfigChanged', 'rateHz': 4, 'logLevel': 'warn'},
      });
      native.add({
        'event': 'configChanged',
        'change': {'type': 'brandNew'},
      });
      await pumpEventQueue();

      expect(triggers.single.zoneId, 'z1');
      expect(triggers.single.triggers.first.payload, {'title': '10%'});
      expect(triggers.single.triggers.last.type, 'generic');
      expect(dwells.single.seconds, 30.0);
      expect(stops, [StopReason.engineFailed]);
      expect(changes[0], isA<RulesChanged>().having((c) => c.zoneId, 'zoneId', 'z1'));
      expect(changes[1], isA<SdkConfigChanged>().having((c) => c.rateHz, 'rateHz', 4));
      expect(changes[2], isA<ResyncNeeded>());
      for (final sub in subs) {
        await sub.cancel();
      }
    });

    test('디버그 로그는 등급과 글을 함께 준다', () async {
      final logs = <DebugLog>[];
      final sub = OneS1ght.onDebugLog.listen(logs.add);
      await pumpEventQueue();
      native.add({'event': 'debugLog', 'level': 'error', 'message': '[E1007] key'});
      native.add({'event': 'debugLog', 'level': 'verbose', 'message': 'x'});
      await pumpEventQueue();
      expect(logs.first.level, LogLevel.error);
      expect(logs.first.message, '[E1007] key');
      expect(logs.last.level, LogLevel.log);
      await sub.cancel();
    });
  });
}
