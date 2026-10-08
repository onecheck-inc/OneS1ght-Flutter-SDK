//
//  Ones1ghtPlugin.swift
//  Flutter ↔ OneS1ght iOS SDK 브리지.
//
//  · 판단은 하지 않는다 — 호출을 SDK 로 넘기고, 결과·오류·이벤트를 채널 값(Map·String)으로 바꾼다.
//  · SDK 는 @MainActor 다. Flutter 는 메인 스레드에서 handle 을 부르므로 메인 액터 Task 로 넘긴다.
//  · 이벤트는 채널 하나로 보낸다({"event": 이름, ...}). Dart 가 듣고 있을 때만 보낸다.
//  · 세션 콜백은 initialize 뒤에 한 번 건다 — FloorSession 은 싱글턴이라 reset·키 교체 뒤에도 그대로다.
//
import Flutter
import OneS1ght
import UIKit

public final class Ones1ghtPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private var sink: FlutterEventSink?
    private var sessionWired = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = Ones1ghtPlugin()
        let methods = FlutterMethodChannel(name: "ones1ght", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methods)
        let events = FlutterEventChannel(name: "ones1ght/events", binaryMessenger: registrar.messenger())
        events.setStreamHandler(instance)
        Task { @MainActor [weak instance] in
            OneS1ght.onDebugLog = { level, line in
                instance?.emit("debugLog", ["level": level.rawValue, "message": line])
            }
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }

    private func emit(_ event: String, _ body: [String: Any?] = [:]) {
        guard let sink else { return }
        var payload: [String: Any] = ["event": event]
        for (k, v) in body { payload[k] = v ?? NSNull() }
        sink(payload)
    }

    // MARK: - 호출

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        Task { @MainActor in
            do {
                result(try await self.dispatch(call.method, args))
            } catch is FlutterMethodNotImplementedError {
                result(FlutterMethodNotImplemented)
            } catch {
                result(Self.flutterError(error))
            }
        }
    }

    @MainActor
    private func dispatch(_ method: String, _ a: [String: Any]) async throws -> Any? {
        switch method {
        case "sdkVersion":
            return OneS1ght.sdkVersion
        case "isInitialized":
            return OneS1ght.isInitialized
        case "deviceAvailability":
            return Self.encode(OneS1ght.deviceAvailability)
        case "googleMapKey":
            return OneS1ght.googleMapKey
        case "requestPermission":
            return Self.encode(await OneS1ght.requestPermission())
        case "setLanguage":
            OneS1ght.setLanguage(a["code"] as? String)
            return nil
        case "initialize":
            let key = try Self.string(a, "sdkKey")
            // 실패해도 세션은 만들어진다(재호출 = 재시도) — 그래서 콜백은 결과와 상관없이 건다.
            defer { wireSessionIfNeeded() }
            if let raw = a["baseUrl"] as? String {
                guard let url = URL(string: raw) else { throw PluginError.badArgument("baseUrl") }
                try await OneS1ght.initialize(sdkKey: key, baseURL: url)
            } else {
                try await OneS1ght.initialize(sdkKey: key)
            }
            return nil
        case "reset":
            await OneS1ght.reset()
            return nil

        case "buildings":
            return try await OneS1ght.buildings().map(Self.encode)
        case "building":
            return Self.encode(try await OneS1ght.building(id: try Self.string(a, "id")))
        case "floors":
            return try await OneS1ght.floors(buildingId: try Self.string(a, "buildingId")).map(Self.encode)
        case "floor":
            return Self.encode(try await OneS1ght.floor(buildingId: try Self.string(a, "buildingId"),
                                                        floorId: try Self.string(a, "floorId")))
        case "zones":
            return try await OneS1ght.zones(buildingId: try Self.string(a, "buildingId"),
                                            floorId: try Self.string(a, "floorId")).map(Self.encode)
        case "zone":
            return Self.encode(try await OneS1ght.zone(buildingId: try Self.string(a, "buildingId"),
                                                       floorId: try Self.string(a, "floorId"),
                                                       zoneId: try Self.string(a, "zoneId")))
        case "locators":
            return Self.encode(try await OneS1ght.locators(buildingId: try Self.string(a, "buildingId"),
                                                           floorId: try Self.string(a, "floorId")))
        case "setFloorMap":
            let floor = (a["floor"] as? [String: Any]).map(Self.decodeFloor)
            try await OneS1ght.setFloorMap(floor, buildingId: a["buildingId"] as? String)
            return nil
        case "refreshZones":
            return await OneS1ght.refreshZones().map(Self.encode)

        case "floorSession":
            _ = try OneS1ght.floorSession()
            wireSessionIfNeeded()
            return nil
        case "session.floor":
            return try OneS1ght.floorSession().floor.map(Self.encode)
        case "session.isRunning":
            return try OneS1ght.floorSession().isRunning
        case "session.isPaused":
            return try OneS1ght.floorSession().isPaused
        case "session.begin":
            wireSessionIfNeeded()
            try await OneS1ght.floorSession().begin()
            return nil
        case "session.pause":
            try OneS1ght.floorSession().pause()
            return nil
        case "session.resume":
            try OneS1ght.floorSession().resume()
            return nil
        case "session.end":
            await (try OneS1ght.floorSession()).end()
            return nil

        case "createProfile":
            return try await OneS1ght.createProfile(Self.stringMap(a["attributes"]))
        case "fetchProfile":
            return try await OneS1ght.fetchProfile(try Self.string(a, "profileId"))
        case "replaceProfile":
            try await OneS1ght.replaceProfile(try Self.string(a, "profileId"),
                                              attributes: Self.stringMap(a["attributes"]))
            return nil
        case "deleteProfile":
            try await OneS1ght.deleteProfile(try Self.string(a, "profileId"))
            return nil
        case "uploadPendingPositions":
            await OneS1ght.uploadPendingPositions()
            return nil
        case "discardPendingPositions":
            OneS1ght.discardPendingPositions()
            return nil
        case "identify":
            OneS1ght.identify(profileId: a["profileId"] as? String)
            return nil
        default:
            throw FlutterMethodNotImplementedError()
        }
    }

    /// 세션 콜백을 채널로 잇는다. 세션이 아직 없으면(initialize 전) 다음 기회에 다시 시도한다.
    @MainActor
    private func wireSessionIfNeeded() {
        guard !sessionWired, let s = try? OneS1ght.floorSession() else { return }
        sessionWired = true
        s.onZoneEnter = { [weak self] z in self?.emit("zoneEnter", ["zone": Self.encode(z)]) }
        s.onZoneExit = { [weak self] z in self?.emit("zoneExit", ["zone": Self.encode(z)]) }
        s.onZoneDwell = { [weak self] z, sec in self?.emit("zoneDwell", ["zone": Self.encode(z), "seconds": sec]) }
        s.onPosition = { [weak self] c in self?.emit("position", ["coordinates": Self.encode(c)]) }
        s.onTriggers = { [weak self] zoneId, triggers in
            self?.emit("triggers", ["zoneId": zoneId, "triggers": triggers.map(Self.encode)])
        }
        s.onFloorDetected = { [weak self] floorId in self?.emit("floorDetected", ["floorId": floorId]) }
        s.onStopped = { [weak self] reason in
            let raw: String
            switch reason {
            case .ended: raw = "ended"
            case .engineFailed: raw = "engineFailed"
            @unknown default: raw = "ended"
            }
            self?.emit("stopped", ["reason": raw])
        }
        s.onConfigChanged = { [weak self] change in self?.emit("configChanged", ["change": Self.encode(change)]) }
    }

    // MARK: - 인자

    private enum PluginError: Error {
        case badArgument(String)
    }

    private struct FlutterMethodNotImplementedError: Error {}

    private static func string(_ a: [String: Any], _ key: String) throws -> String {
        guard let v = a[key] as? String else { throw PluginError.badArgument(key) }
        return v
    }

    private static func stringMap(_ v: Any?) -> [String: String] {
        guard let m = v as? [String: Any] else { return [:] }
        return m.reduce(into: [:]) { out, e in out[e.key] = (e.value as? String) ?? "\(e.value)" }
    }

    private static func decodeFloor(_ m: [String: Any]) -> Floor {
        Floor(id: m["id"] as? String ?? "",
              name: m["name"] as? String ?? "",
              image: (m["image"] as? FlutterStandardTypedData)?.data,
              hasPlan: m["hasPlan"] as? Bool ?? false,
              originX: (m["originX"] as? NSNumber)?.doubleValue ?? 0,
              originY: (m["originY"] as? NSNumber)?.doubleValue ?? 0,
              widthM: (m["widthM"] as? NSNumber)?.doubleValue ?? 0,
              heightM: (m["heightM"] as? NSNumber)?.doubleValue ?? 0)
    }

    // MARK: - 값 → 채널

    private static func encode(_ v: OneS1ght.DeviceAvailability) -> String {
        switch v {
        case .available: return "available"
        case .osVersionTooLow: return "osVersionTooLow"
        case .deviceNotSupported: return "deviceNotSupported"
        }
    }

    private static func encode(_ v: PermissionStatus) -> String {
        switch v {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .unsupported: return "unsupported"
        }
    }

    private static func encode(_ b: Building) -> [String: Any?] {
        ["id": b.id, "name": b.name, "floorCount": b.floorCount]
    }

    private static func encode(_ f: Floor) -> [String: Any?] {
        ["id": f.id, "name": f.name,
         "image": f.image.map { FlutterStandardTypedData(bytes: $0) },
         "hasPlan": f.hasPlan,
         "originX": f.originX, "originY": f.originY, "widthM": f.widthM, "heightM": f.heightM]
    }

    private static func encode(_ z: Zone) -> [String: Any?] {
        ["id": z.id, "name": z.name,
         "polygon": z.polygon.map { ["x": $0.x, "y": $0.y] },
         "inDist": z.inDist, "inCount": z.inCount, "inCountInterval": z.inCountInterval,
         "outPeriod": z.outPeriod, "priority": z.priority, "callInout": z.callInout,
         "dwellSeconds": z.dwellSeconds]
    }

    private static func encode(_ l: FloorLocators) -> [String: Any?] {
        ["locators": l.locators.map { ["address": $0.address, "x": $0.x, "y": $0.y, "z": $0.z, "isPlaced": $0.isPlaced] },
         "sessionId": l.sessionId]
    }

    private static func encode(_ c: Coordinates) -> [String: Any] {
        ["x": c.x, "y": c.y, "z": c.z]
    }

    private static func encode(_ t: Trigger) -> [String: Any?] {
        ["triggerId": t.triggerId, "type": t.type, "payload": t.payload]
    }

    private static func encode(_ c: ConfigChange) -> [String: Any?] {
        switch c {
        case .zonesChanged(let floorId): return ["type": "zonesChanged", "floorId": floorId]
        case .planChanged(let floorId): return ["type": "planChanged", "floorId": floorId]
        case .rulesChanged(let zoneId): return ["type": "rulesChanged", "zoneId": zoneId]
        case .sdkConfigChanged(let rateHz, let logLevel):
            return ["type": "sdkConfigChanged", "rateHz": rateHz, "logLevel": logLevel]
        case .resyncNeeded: return ["type": "resyncNeeded"]
        }
    }

    // MARK: - 오류 → 채널

    /// SDK 오류는 E-코드를 그대로 넘긴다 — Android 와 같은 코드라 앱은 플랫폼을 가리지 않고 분기한다.
    private static func flutterError(_ error: Error) -> FlutterError {
        if let e = error as? SdkError {
            return FlutterError(code: e.code.rawValue, message: "\(e)",
                                details: ["kind": "sdk", "name": "\(e)"])
        }
        if let e = error as? ApiError {
            var details: [String: Any] = ["kind": "api", "name": apiName(e)]
            switch e {
            case .invalidKey(let d), .forbidden(let d), .notFound(let d), .unprocessable(let d), .decoding(let d):
                if let d { details["detail"] = d }
            case .server(let status, let d):
                details["status"] = status
                if let d { details["detail"] = d }
            case .network:
                break
            }
            return FlutterError(code: e.code.rawValue, message: e.description, details: details)
        }
        if case PluginError.badArgument(let key) = error {
            return FlutterError(code: "internal", message: "missing or invalid argument: \(key)",
                                details: ["kind": "plugin", "name": "badArgument"])
        }
        return FlutterError(code: "internal", message: "\(error)", details: ["kind": "plugin", "name": "unknown"])
    }

    private static func apiName(_ e: ApiError) -> String {
        switch e {
        case .invalidKey: return "invalidKey"
        case .forbidden: return "forbidden"
        case .notFound: return "notFound"
        case .unprocessable: return "unprocessable"
        case .server: return "server"
        case .network: return "network"
        case .decoding: return "decoding"
        }
    }
}
