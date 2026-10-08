// swift-tools-version: 5.9
//
//  OneS1ght Flutter 플러그인 — iOS 쪽.
//
//  · OneS1ght iOS SDK 를 SPM 으로 붙인다. 측위·판정 엔진은 그 패키지가 함께 끌고 온다.
//  · SPM 전용이다 — CocoaPods 로는 엔진의 동적 프레임워크가 앱에 실리지 않아 실행 즉시 죽을 수 있다.
//    그래서 podspec 은 설치를 막고 안내만 한다(../ones1ght_sdk.podspec).
//  · 네이티브 SDK 버전은 exact 로 고정한다 — 범위 참조는 앱 빌드를 조용히 바꾼다.
//  · ⚠️ 이 패키지·타깃 이름을 `ones1ght` 로 하지 말 것. Flutter 는 플러그인 이름 그대로 `@import` 하는데,
//    SDK 모듈 `OneS1ght` 와 대소문자만 달라 macOS 기본 볼륨(대소문자 무시)에서 빌드 산출물이 겹친다 —
//    리소스 번들이 섞이고 `import OneS1ght` 가 이 플러그인 자신을 가리켜 컴파일이 깨진다(2026-10-08 실측).
//
import PackageDescription

let package = Package(
    name: "ones1ght_sdk",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .library(name: "ones1ght-sdk", targets: ["ones1ght_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/onecheck-inc/OneS1ght-iOS-SDK", exact: "0.2.2"),
    ],
    targets: [
        .target(
            name: "ones1ght_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "OneS1ght", package: "OneS1ght-iOS-SDK"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        )
    ]
)
