// OneS1ght Flutter 예제 — 초기화 → 권한 → 층 지정 → 측위 시작 흐름을 버튼으로 하나씩 해 본다.
//
// SDK 키는 코드에 넣지 않고 실행할 때 넘긴다:
//   flutter run --dart-define=ONES1GHT_SDK_KEY=ock_sdk_…
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ones1ght_sdk/ones1ght_sdk.dart';

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

  @override
  void initState() {
    super.initState();
    _subs.add(OneS1ght.onDebugLog.listen((l) => _add('SDK $l')));
    _refreshStatus();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _add(String line) => setState(() => _log.insert(0, line));

  Future<void> _refreshStatus() async {
    final version = await OneS1ght.sdkVersion();
    final availability = await OneS1ght.deviceAvailability();
    final initialized = await OneS1ght.isInitialized();
    setState(
      () => _status =
          'plugin ${OneS1ght.pluginVersion} · SDK $version\n'
          'device: ${availability.name} · initialized: $initialized',
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
    final session = await OneS1ght.floorSession();
    _subs
      ..add(session.onFloorDetected.listen((id) => _add('floor detected: $id')))
      ..add(session.onZoneEnter.listen((z) => _add('IN  ${z.name}')))
      ..add(session.onZoneExit.listen((z) => _add('OUT ${z.name}')))
      ..add(session.onTriggers.listen((t) => _add('triggers ${t.zoneId}: ${t.triggers.map((e) => e.type)}')))
      ..add(session.onStopped.listen((r) => _add('stopped: ${r.name}')));
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
    final id = await OneS1ght.createProfile({'source': 'flutter-example'});
    await OneS1ght.identify(profileId: id);
    await (await OneS1ght.floorSession()).begin();
  });

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
