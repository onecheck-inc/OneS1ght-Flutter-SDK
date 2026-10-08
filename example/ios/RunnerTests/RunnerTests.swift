import Flutter
import UIKit
import XCTest

@testable import ones1ght_sdk

// 채널 계약을 Swift 쪽에서 본다 — 같은 호출을 Dart 테스트(test/)는 흉내 낸 네이티브로, 이 테스트는 진짜 SDK 로 받는다.
class RunnerTests: XCTestCase {

  private func call(_ method: String, _ args: Any? = nil) -> Any? {
    let plugin = Ones1ghtPlugin()
    let done = expectation(description: method)
    var value: Any?
    plugin.handle(FlutterMethodCall(methodName: method, arguments: args)) { result in
      value = result
      done.fulfill()
    }
    waitForExpectations(timeout: 5)
    return value
  }

  func testSdkVersionComesFromNativeSdk() {
    let version = call("sdkVersion") as? String
    XCTAssertNotNil(version)
    XCTAssertFalse(version?.isEmpty ?? true)
  }

  func testFloorSessionBeforeInitializeIsE1001() {
    let error = call("floorSession") as? FlutterError
    XCTAssertEqual(error?.code, "E1001")
    XCTAssertEqual((error?.details as? [String: Any])?["kind"] as? String, "sdk")
  }

  func testMissingArgumentIsPluginError() {
    let error = call("floors", [String: Any]()) as? FlutterError
    XCTAssertEqual(error?.code, "internal")
  }

  func testUnknownMethodIsNotImplemented() {
    XCTAssertTrue(call("noSuchMethod") as AnyObject === FlutterMethodNotImplemented as AnyObject)
  }
}
