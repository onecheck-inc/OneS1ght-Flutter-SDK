//
//  errors.dart
//  네이티브 SDK 오류 → Dart 예외 하나.
//
//  네이티브 SDK 는 오류마다 E-코드(E1001 등)를 갖고, iOS·Android 가 같은 코드를 쓴다.
//  플러그인은 그 코드를 PlatformException.code 로 그대로 넘기고, 여기서 [OneS1ghtException] 으로 바꾼다.
//  앱은 [code] 로 분기하면 플랫폼을 가리지 않는다.
//
import 'package:flutter/services.dart';

/// SDK 오류. [code] 는 네이티브 SDK 의 오류 코드(`E1001` 등)이며 iOS·Android 가 같다.
class OneS1ghtException implements Exception {
  const OneS1ghtException({required this.code, required this.message, this.kind, this.name, this.status, this.detail});

  /// 오류 코드 — `E1001`(미초기화) · `E1002`(키 무효) · `E1004`(프로필 미연결) · `E2001`(OS 낮음) ·
  /// `E2002`(기기 미지원) · `E3001`(층 미지정) · `E5001`(네트워크) 등. 플러그인 자체 오류는
  /// [unsupportedActivity]·[internal] 이다.
  final String code;

  /// 사람이 읽는 설명(네이티브 SDK 의 문구).
  final String message;

  /// `sdk`(SDK 상태 오류) · `api`(서버 응답 오류) · `plugin`(이 플러그인).
  final String? kind;

  /// 오류 이름 — `notInitialized` · `invalidKey` · `server` 등.
  final String? name;

  /// 서버 오류의 HTTP 상태.
  final int? status;

  /// 서버가 준 세부 사유.
  final String? detail;

  /// Android — 권한 요청에 `ComponentActivity` 가 필요한데 앱의 Activity 가 아니다(README 참고).
  static const String unsupportedActivity = 'unsupportedActivity';

  /// 플러그인이 예상하지 못한 오류.
  static const String internal = 'internal';

  static OneS1ghtException fromPlatform(PlatformException e) {
    final d = e.details;
    final m = d is Map ? d : const {};
    return OneS1ghtException(
      code: e.code,
      message: e.message ?? e.code,
      kind: m['kind'] as String?,
      name: m['name'] as String?,
      status: m['status'] is num ? (m['status'] as num).toInt() : null,
      detail: m['detail'] as String?,
    );
  }

  @override
  String toString() => 'OneS1ghtException($code): $message';
}
