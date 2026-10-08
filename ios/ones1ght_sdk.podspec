#
# OneS1ght Flutter 플러그인은 iOS 에서 Swift Package Manager 로만 붙는다(ones1ght/Package.swift).
#
# CocoaPods 로 붙이면 측위 엔진의 동적 프레임워크가 앱에 실리지 않아 실행 즉시 죽을 수 있다.
# 그래서 이 podspec 은 설치를 막고 켜는 방법을 알려 준다 — 조용히 깨진 앱이 만들어지는 것보다 낫다.
#
Pod::Spec.new do |s|
  raise <<~MSG
    [ones1ght] This plugin supports iOS only through Swift Package Manager.
      Flutter 3.44+ enables it by default. If it was turned off, run:
        flutter config --enable-swift-package-manager
      then rebuild. CocoaPods is not supported.
  MSG
end
