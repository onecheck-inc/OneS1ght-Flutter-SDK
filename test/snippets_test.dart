// MCP(onesight_snippet · onesight_migrate)가 태그에서 읽는 파일을 지킨다.
//
// MCP 는 `v{버전}/Snippets/flutter.json` 을 읽는다 — 태그는 옮기지 않으므로 틀린 채 태그되면 다음 판까지 고칠 수 없다.
// 그래서 판올림 PR 에서 버전·단계·코드 모양을 여기서 먼저 막는다. 코드 조각이 실제로 컴파일되는지는
// 판올림 때 별도 앱에 붙여 `flutter analyze` 로 본다(이 테스트는 플러그인 의존성만 가진다).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ones1ght_sdk/ones1ght_sdk.dart';

Map<String, Object?> _json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

String _pubspecVersion() =>
    RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;

void main() {
  final snippets = _json('Snippets/flutter.json');
  final migrations = _json('Migrations/flutter.json');
  final steps = (snippets['steps']! as List).cast<Map<String, Object?>>();
  final version = _pubspecVersion();

  test('버전이 pubspec · pluginVersion · 스니펫 · 마이그레이션에서 같다', () {
    expect(OneS1ght.pluginVersion, version);
    expect(snippets['sdkVersion'], version);
    expect(migrations['currentVersion'], version);
    expect(snippets['platform'], 'flutter');
    expect(migrations['platform'], 'flutter');
  });

  test('마이그레이션 마지막 칸이 이 판으로 끝나고 칸이 이어진다', () {
    final list = (migrations['migrations']! as List).cast<Map<String, Object?>>();
    expect(list.last['to'], version);
    for (var i = 1; i < list.length; i++) {
      expect(list[i]['from'], list[i - 1]['to'], reason: '칸 $i 가 앞 칸과 이어지지 않는다');
    }
  });

  test('네이티브 스니펫과 같은 12단계가 순서대로 있다', () {
    expect(steps.map((s) => s['id']), [
      'install',
      'permission',
      'initialize',
      'profile',
      'selectFloor',
      'drawMap',
      'begin',
      'end',
      'pause',
      'configChange',
      'deviceCheck',
      'debugLog',
    ]);
    expect(steps.map((s) => s['order']), List.generate(12, (i) => i + 1));
  });

  test('throws 는 E-코드 모양이다', () {
    for (final s in steps) {
      for (final code in (s['throws'] as List? ?? const [])) {
        expect(code, matches(RegExp(r'^E\d{4}$')), reason: '${s['id']}');
      }
    }
  });

  test('설치 줄이 이 판을 받는다 — 0.0.x 의 ^ 는 그 판 하나만 받는다', () {
    final install = steps.first;
    final pubspec = (install['files']! as List).cast<Map<String, Object?>>().firstWhere(
      (f) => f['path'] == 'pubspec.yaml',
    );
    expect(pubspec['code'] as String, contains('ones1ght_sdk: ^$version'));
    expect(File('README.md').readAsStringSync(), contains('ones1ght_sdk: ^$version'));
    expect(File('README.ko.md').readAsStringSync(), contains('ones1ght_sdk: ^$version'));
  });

  test('옛 import 경로·공급사 이름이 없다', () {
    final raw = File('Snippets/flutter.json').readAsStringSync();
    expect(raw, isNot(contains("package:ones1ght_sdk/ones1ght.dart'")));
    for (final vendor in ['Geoplan', 'IntelligenceHub', 'ihub', 'GeoSpace']) {
      expect(raw.toLowerCase(), isNot(contains(vendor.toLowerCase())), reason: vendor);
    }
  });
}
