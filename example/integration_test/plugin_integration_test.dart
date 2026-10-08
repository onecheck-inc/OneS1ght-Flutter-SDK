// 실기기·시뮬레이터·에뮬레이터에서 네이티브 SDK 까지 실제로 닿는지 본다(키 없이 도는 것만).
//
//   cd example && flutter test integration_test -d <기기>
//
// 측위(UWB) 자체는 지원 기기 + 설치된 매장이 있어야 해서 여기서 보지 않는다.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ones1ght_sdk/ones1ght_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('네이티브 SDK 버전이 온다', (tester) async {
    final version = await OneS1ght.sdkVersion();
    expect(version, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });

  testWidgets('기기 판정은 던지지 않는다', (tester) async {
    final availability = await OneS1ght.deviceAvailability();
    expect(DeviceAvailability.values, contains(availability));
  });

  testWidgets('초기화 전에는 세션이 E1001 로 막힌다', (tester) async {
    expect(await OneS1ght.isInitialized(), isFalse);
    await expectLater(
      OneS1ght.floorSession(),
      throwsA(isA<OneS1ghtException>().having((e) => e.code, 'code', 'E1001').having((e) => e.kind, 'kind', 'sdk')),
    );
  });

  testWidgets('초기화 전 조회도 E1001 이다', (tester) async {
    await expectLater(OneS1ght.buildings(), throwsA(isA<OneS1ghtException>().having((e) => e.code, 'code', 'E1001')));
  });

  testWidgets('측위가 안 되는 기기에서는 권한 창 없이 unsupported 다', (tester) async {
    // 시뮬레이터·에뮬레이터는 UWB 가 없어 이 경로를 탄다. 지원 기기에서는 시스템 창이 떠서 건너뛴다.
    if (await OneS1ght.deviceAvailability() == DeviceAvailability.available) return;
    expect(await OneS1ght.requestPermission(), PermissionStatus.unsupported);
  });
}
