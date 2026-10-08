//
//  channel.dart
//  네이티브 플러그인과의 통로 — 호출 하나(MethodChannel) + 이벤트 하나(EventChannel).
//
//  · 이벤트는 채널 하나로 모두 온다({'event': 이름, ...}). 앱이 구독하는 스트림은 여기서 이름으로 갈라 낸다.
//  · 네이티브는 Dart 가 듣고 있을 때만 보낸다 — 듣기 전에 일어난 이벤트는 쌓이지 않는다.
//
import 'dart:async';

import 'package:flutter/services.dart';

import 'errors.dart';

const MethodChannel methodChannel = MethodChannel('ones1ght');
const EventChannel eventChannel = EventChannel('ones1ght/events');

/// 호출 — 네이티브 오류는 [OneS1ghtException] 으로 바꿔 던진다.
Future<T?> invoke<T>(String method, [Map<String, Object?>? args]) async {
  try {
    return await methodChannel.invokeMethod<T>(method, args);
  } on PlatformException catch (e) {
    throw OneS1ghtException.fromPlatform(e);
  }
}

Stream<Map<Object?, Object?>>? _events;

/// 모든 네이티브 이벤트 — 구독자가 하나라도 있는 동안만 네이티브 쪽 수신이 열린다.
Stream<Map<Object?, Object?>> get nativeEvents =>
    _events ??= eventChannel.receiveBroadcastStream().where((e) => e is Map).cast<Map<Object?, Object?>>();

/// 이름이 [name] 인 이벤트만.
Stream<Map<Object?, Object?>> eventsNamed(String name) => nativeEvents.where((e) => e['event'] == name);
