// OneS1ght Flutter 예제 — 초기화 → 권한 → 층 지정 → 측위 시작 흐름을 버튼으로 하나씩 해 본다.
//
// SDK 키는 코드에 넣지 않고 실행할 때 넘긴다:
//   flutter run --dart-define=ONES1GHT_SDK_KEY=ock_sdk_…
//
// 화면에 보이는 로그는 앱 Documents/ones1ght-example.log 에도 쌓인다 — 릴리스 빌드는 print 가 콘솔로 나오지 않아
// 기기 밖에서 보려면 파일을 꺼내야 한다(README).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ones1ght_sdk/ones1ght_sdk.dart';
import 'package:path_provider/path_provider.dart';

const _sdkKey = String.fromEnvironment('ONES1GHT_SDK_KEY');

void main() => runApp(const MaterialApp(home: ExamplePage()));

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  final _log = <String>[];
  final _subs = <StreamSubscription<Object?>>[];
  String _status = '';
  File? _logFile;
  Directory? _docs;
  bool _sessionWired = false;
  int _positions = 0;
  Coordinates? _lastPosition;

  @override
  void initState() {
    super.initState();
    _subs.add(OneS1ght.onDebugLog.listen((l) => _add('SDK $l')));
    getApplicationDocumentsDirectory().then((dir) {
      _docs = dir;
      _logFile = File('${dir.path}/ones1ght-example.log');
      _add('log file: ${_logFile!.path}');
    });
    _refreshStatus();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// 화면 목록·콘솔·로그 파일에 같이 남긴다.
  void _add(String line) {
    final t = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('[ones1ght-example] $t $line');
    _logFile?.writeAsStringSync('$t $line\n', mode: FileMode.append, flush: true);
    if (mounted) setState(() => _log.insert(0, '$t $line'));
  }

  Future<void> _refreshStatus() async {
    final version = await OneS1ght.sdkVersion();
    final availability = await OneS1ght.deviceAvailability();
    final initialized = await OneS1ght.isInitialized();
    final running = initialized && await (await OneS1ght.floorSession()).isRunning();
    final p = _lastPosition;
    if (!mounted) return;
    setState(
      () => _status =
          'plugin ${OneS1ght.pluginVersion} · SDK $version\n'
          'device: ${availability.name} · initialized: $initialized · running: $running\n'
          'positions: $_positions${p == null ? '' : ' · last (${p.x.toStringAsFixed(2)}, ${p.y.toStringAsFixed(2)})'}',
    );
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      _add('✓ $label');
    } on OneS1ghtException catch (e) {
      _add('✗ $label — ${e.code} ${e.message}');
    }
    await _refreshStatus();
  }

  Future<void> _initialize() => _run('initialize', () async {
    if (_sdkKey.isEmpty) throw const OneS1ghtException(code: 'example', message: 'ONES1GHT_SDK_KEY 를 넘겨 실행하세요');
    await OneS1ght.initialize(sdkKey: _sdkKey);
    // 다시 눌러도 구독은 한 번만 — 두 번 걸면 같은 이벤트가 두 줄씩 찍힌다.
    if (_sessionWired) return;
    _sessionWired = true;
    final session = await OneS1ght.floorSession();
    _subs
      ..add(session.onFloorDetected.listen((id) => _add('floor detected: $id')))
      ..add(session.onZoneEnter.listen((z) => _add('IN  ${z.name}')))
      ..add(session.onZoneExit.listen((z) => _add('OUT ${z.name}')))
      ..add(session.onZoneDwell.listen((d) => _add('DWELL ${d.zone.name} ${d.seconds}s')))
      ..add(session.onTriggers.listen((t) => _add('triggers ${t.zoneId}: ${t.triggers.map((e) => e.type)}')))
      ..add(session.onConfigChanged.listen((c) => _add('config changed: ${c.runtimeType}')))
      ..add(session.onStopped.listen((r) => _add('stopped: ${r.name}')))
      // 좌표는 초당 여러 번 와서 줄로 찍지 않고 상태 줄에 개수·마지막 값만 보인다.
      ..add(
        session.onPosition.listen((c) {
          _positions++;
          _lastPosition = c;
          if (_positions % 20 == 1) _refreshStatus();
        }),
      );
  });

  Future<void> _permission() => _run('requestPermission', () async {
    _add('permission: ${(await OneS1ght.requestPermission()).name}');
  });

  Future<void> _firstFloor() => _run('setFloorMap(첫 층)', () async {
    final buildings = await OneS1ght.buildings();
    if (buildings.isEmpty) throw const OneS1ghtException(code: 'example', message: '건물 없음');
    final floors = await OneS1ght.floors(buildingId: buildings.first.id);
    if (floors.isEmpty) throw const OneS1ghtException(code: 'example', message: '층 없음');
    await OneS1ght.setFloorMap(floors.first, buildingId: buildings.first.id);
    _add('floor: ${buildings.first.name} / ${floors.first.name}');
  });

  Future<void> _begin() => _run('begin', () async {
    final session = await OneS1ght.floorSession();
    if (await session.isRunning()) {
      _add('이미 측위 중 — end 후 다시 시작하세요');
      return;
    }
    await OneS1ght.identify(profileId: await _profileId());
    await session.begin();
  });

  /// 프로필은 설치당 한 번만 만들고 파일에 보관해 재사용한다 — begin 마다 만들면 서버에 프로필이 쌓인다.
  Future<String> _profileId() async {
    final file = File('${(_docs ?? await getApplicationDocumentsDirectory()).path}/ones1ght-example-profile.txt');
    if (file.existsSync()) {
      final saved = file.readAsStringSync().trim();
      if (saved.isNotEmpty) return saved;
    }
    final id = await OneS1ght.createProfile({'source': 'flutter-example'});
    file.writeAsStringSync(id);
    _add('profile created: $id');
    return id;
  }

  Future<void> _end() => _run('end', () async => (await OneS1ght.floorSession()).end());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('OneS1ght')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_status, key: const Key('status')),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _initialize, child: const Text('initialize')),
              FilledButton(onPressed: _permission, child: const Text('permission')),
              FilledButton(onPressed: _firstFloor, child: const Text('first floor')),
              FilledButton(onPressed: _begin, child: const Text('begin')),
              OutlinedButton(onPressed: _end, child: const Text('end')),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: ListView(children: [for (final l in _log) Text(l, style: const TextStyle(fontSize: 12))]),
          ),
        ],
      ),
    ),
  );
}
