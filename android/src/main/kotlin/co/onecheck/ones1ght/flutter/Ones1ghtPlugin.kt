package co.onecheck.ones1ght.flutter

//
//  Ones1ghtPlugin.kt
//  Flutter ↔ OneS1ght Android SDK 브리지.
//
//  · 판단은 하지 않는다 — 호출을 SDK 로 넘기고, 결과·오류·이벤트를 채널 값(Map·String)으로 바꾼다.
//  · SDK 의 suspend 함수는 메인 스코프에서 부른다. SDK 콜백도 메인 스레드에서 오므로 그대로 채널로 보낸다.
//  · 이벤트는 채널 하나로 보낸다({"event": 이름, ...}). Dart 가 듣고 있을 때만 보낸다.
//  · 세션 리스너는 initialize 뒤에 한 번 건다 — FloorSession 은 싱글턴이라 reset·키 교체 뒤에도 그대로다.
//  · 권한 요청은 SDK 가 ComponentActivity 를 요구한다 — Flutter 앱은 FlutterFragmentActivity 를 써야 한다.
//
import android.app.Activity
import android.content.Context
import androidx.activity.ComponentActivity
import co.onecheck.ones1ght.android.ConfigChangeListener
import co.onecheck.ones1ght.android.DebugLogListener
import co.onecheck.ones1ght.android.DeviceAvailability
import co.onecheck.ones1ght.android.DwellListener
import co.onecheck.ones1ght.android.FloorSession
import co.onecheck.ones1ght.android.OneS1ght
import co.onecheck.ones1ght.android.PermissionStatus
import co.onecheck.ones1ght.android.PositionListener
import co.onecheck.ones1ght.android.SdkError
import co.onecheck.ones1ght.android.SessionFloorListener
import co.onecheck.ones1ght.android.SessionStoppedListener
import co.onecheck.ones1ght.android.TriggersListener
import co.onecheck.ones1ght.android.ZoneListener
import co.onecheck.ones1ght.android.model.Building
import co.onecheck.ones1ght.android.model.ConfigChange
import co.onecheck.ones1ght.android.model.Coordinates
import co.onecheck.ones1ght.android.model.Floor
import co.onecheck.ones1ght.android.model.FloorLocators
import co.onecheck.ones1ght.android.model.Trigger
import co.onecheck.ones1ght.android.model.Zone
import co.onecheck.ones1ght.android.network.ApiError
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

public class Ones1ghtPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ActivityAware {

    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var sink: EventChannel.EventSink? = null
    private var sessionWired = false
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "ones1ght").also { it.setMethodCallHandler(this) }
        events = EventChannel(binding.binaryMessenger, "ones1ght/events").also { it.setStreamHandler(this) }
        OneS1ght.onDebugLog = DebugLogListener { level, message ->
            emit("debugLog", mapOf("level" to level.raw, "message" to message))
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        OneS1ght.onDebugLog = null
        scope.cancel()
    }

    // MARK: - ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // MARK: - EventChannel

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun emit(event: String, body: Map<String, Any?> = emptyMap()) {
        sink?.success(mapOf("event" to event) + body)
    }

    // MARK: - 호출

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val value = dispatch(call)
                if (value === NotImplemented) result.notImplemented() else result.success(value)
            } catch (e: Throwable) {
                val (code, message, details) = flutterError(e)
                result.error(code, message, details)
            }
        }
    }

    private object NotImplemented

    private suspend fun dispatch(call: MethodCall): Any? = when (call.method) {
        "sdkVersion" -> OneS1ght.SDK_VERSION
        "isInitialized" -> OneS1ght.isInitialized
        "deviceAvailability" -> encode(OneS1ght.deviceAvailability)
        "googleMapKey" -> OneS1ght.googleMapKey
        "requestPermission" -> {
            val a = activity as? ComponentActivity ?: throw UnsupportedActivity()
            encode(OneS1ght.requestPermission(a))
        }
        "setLanguage" -> {
            OneS1ght.setLanguage(call.argument<String>("code"))
            null
        }
        "initialize" -> {
            val key = call.requireString("sdkKey")
            val baseUrl = call.argument<String>("baseUrl")
            // 실패해도 세션은 만들어진다(재호출 = 재시도) — 그래서 리스너는 결과와 상관없이 건다.
            try {
                if (baseUrl != null) OneS1ght.initialize(context, key, baseUrl) else OneS1ght.initialize(context, key)
            } finally {
                wireSessionIfNeeded()
            }
            null
        }
        "reset" -> {
            OneS1ght.reset()
            null
        }

        "buildings" -> OneS1ght.buildings().map(::encode)
        "building" -> encode(OneS1ght.building(call.requireString("id")))
        "floors" -> OneS1ght.floors(call.requireString("buildingId")).map(::encode)
        "floor" -> encode(OneS1ght.floor(call.requireString("buildingId"), call.requireString("floorId")))
        "zones" -> OneS1ght.zones(call.requireString("buildingId"), call.requireString("floorId")).map(::encode)
        "zone" -> encode(
            OneS1ght.zone(call.requireString("buildingId"), call.requireString("floorId"), call.requireString("zoneId")),
        )
        "locators" -> encode(OneS1ght.locators(call.requireString("buildingId"), call.requireString("floorId")))
        "setFloorMap" -> {
            val floor = call.argument<Map<String, Any?>>("floor")?.let(::decodeFloor)
            OneS1ght.setFloorMap(floor, call.argument<String>("buildingId"))
            null
        }
        "refreshZones" -> OneS1ght.refreshZones().map(::encode)

        "floorSession" -> {
            OneS1ght.floorSession()
            wireSessionIfNeeded()
            null
        }
        "session.floor" -> OneS1ght.floorSession().floor?.let(::encode)
        "session.isRunning" -> OneS1ght.floorSession().isRunning
        "session.isPaused" -> OneS1ght.floorSession().isPaused
        "session.begin" -> {
            wireSessionIfNeeded()
            OneS1ght.floorSession().begin()
            null
        }
        "session.pause" -> {
            OneS1ght.floorSession().pause()
            null
        }
        "session.resume" -> {
            OneS1ght.floorSession().resume()
            null
        }
        "session.end" -> {
            OneS1ght.floorSession().end()
            null
        }

        "createProfile" -> OneS1ght.createProfile(call.stringMap("attributes"))
        "fetchProfile" -> OneS1ght.fetchProfile(call.requireString("profileId"))
        "replaceProfile" -> {
            OneS1ght.replaceProfile(call.requireString("profileId"), call.stringMap("attributes"))
            null
        }
        "deleteProfile" -> {
            OneS1ght.deleteProfile(call.requireString("profileId"))
            null
        }
        "uploadPendingPositions" -> {
            OneS1ght.uploadPendingPositions()
            null
        }
        "discardPendingPositions" -> {
            OneS1ght.discardPendingPositions()
            null
        }
        "identify" -> {
            OneS1ght.identify(call.argument<String>("profileId"))
            null
        }
        else -> NotImplemented
    }

    /** 세션 리스너를 채널로 잇는다. 세션이 아직 없으면(initialize 전) 다음 기회에 다시 시도한다. */
    private fun wireSessionIfNeeded() {
        if (sessionWired) return
        val s = runCatching { OneS1ght.floorSession() }.getOrNull() ?: return
        sessionWired = true
        s.onZoneEnter = ZoneListener { emit("zoneEnter", mapOf("zone" to encode(it))) }
        s.onZoneExit = ZoneListener { emit("zoneExit", mapOf("zone" to encode(it))) }
        s.onZoneDwell = DwellListener { zone, seconds ->
            emit("zoneDwell", mapOf("zone" to encode(zone), "seconds" to seconds))
        }
        s.onPosition = PositionListener { emit("position", mapOf("coordinates" to encode(it))) }
        s.onTriggers = TriggersListener { zoneId, triggers ->
            emit("triggers", mapOf("zoneId" to zoneId, "triggers" to triggers.map(::encode)))
        }
        s.onFloorDetected = SessionFloorListener { emit("floorDetected", mapOf("floorId" to it)) }
        s.onStopped = SessionStoppedListener {
            val raw = when (it) {
                FloorSession.StopReason.ENGINE_FAILED -> "engineFailed"
                else -> "ended"
            }
            emit("stopped", mapOf("reason" to raw))
        }
        s.onConfigChanged = ConfigChangeListener {
            emit("configChanged", mapOf("change" to encode(it)))
        }
    }

    // MARK: - 인자

    private class BadArgument(val key: String) : IllegalArgumentException("missing or invalid argument: $key")

    private class UnsupportedActivity :
        IllegalStateException(
            "requestPermission needs a ComponentActivity — make MainActivity extend FlutterFragmentActivity",
        )

    private fun MethodCall.requireString(key: String): String = argument<String>(key) ?: throw BadArgument(key)

    private fun MethodCall.stringMap(key: String): Map<String, String> =
        argument<Map<String, Any?>>(key)?.mapValues { it.value?.toString() ?: "" } ?: emptyMap()

    private fun decodeFloor(m: Map<String, Any?>): Floor = Floor(
        id = m["id"] as? String ?: "",
        name = m["name"] as? String ?: "",
        image = m["image"] as? ByteArray,
        hasPlan = m["hasPlan"] as? Boolean ?: false,
        originX = (m["originX"] as? Number)?.toDouble() ?: 0.0,
        originY = (m["originY"] as? Number)?.toDouble() ?: 0.0,
        widthM = (m["widthM"] as? Number)?.toDouble() ?: 0.0,
        heightM = (m["heightM"] as? Number)?.toDouble() ?: 0.0,
    )

    // MARK: - 값 → 채널

    private fun encode(v: DeviceAvailability): String = when (v) {
        DeviceAvailability.AVAILABLE -> "available"
        DeviceAvailability.OS_VERSION_TOO_LOW -> "osVersionTooLow"
        DeviceAvailability.DEVICE_NOT_SUPPORTED -> "deviceNotSupported"
    }

    private fun encode(v: PermissionStatus): String = when (v) {
        PermissionStatus.AUTHORIZED -> "authorized"
        PermissionStatus.DENIED -> "denied"
        PermissionStatus.UNSUPPORTED -> "unsupported"
    }

    private fun encode(b: Building): Map<String, Any?> = mapOf("id" to b.id, "name" to b.name, "floorCount" to b.floorCount)

    private fun encode(f: Floor): Map<String, Any?> = mapOf(
        "id" to f.id, "name" to f.name, "image" to f.image, "hasPlan" to f.hasPlan,
        "originX" to f.originX, "originY" to f.originY, "widthM" to f.widthM, "heightM" to f.heightM,
    )

    private fun encode(z: Zone): Map<String, Any?> = mapOf(
        "id" to z.id, "name" to z.name,
        "polygon" to z.polygon.map { mapOf("x" to it.x, "y" to it.y) },
        "inDist" to z.inDist, "inCount" to z.inCount, "inCountInterval" to z.inCountInterval,
        "outPeriod" to z.outPeriod, "priority" to z.priority, "callInout" to z.callInout,
        "dwellSeconds" to z.dwellSeconds,
    )

    private fun encode(l: FloorLocators): Map<String, Any?> = mapOf(
        "locators" to l.locators.map {
            mapOf("address" to it.address, "x" to it.x, "y" to it.y, "z" to it.z, "isPlaced" to it.isPlaced)
        },
        "sessionId" to l.sessionId,
    )

    private fun encode(c: Coordinates): Map<String, Any?> = mapOf("x" to c.x, "y" to c.y, "z" to c.z)

    private fun encode(t: Trigger): Map<String, Any?> =
        mapOf("triggerId" to t.triggerId, "type" to t.type, "payload" to t.payload)

    private fun encode(c: ConfigChange): Map<String, Any?> = when (c) {
        is ConfigChange.ZonesChanged -> mapOf("type" to "zonesChanged", "floorId" to c.floorId)
        is ConfigChange.PlanChanged -> mapOf("type" to "planChanged", "floorId" to c.floorId)
        is ConfigChange.RulesChanged -> mapOf("type" to "rulesChanged", "zoneId" to c.zoneId)
        is ConfigChange.SdkConfigChanged ->
            mapOf("type" to "sdkConfigChanged", "rateHz" to c.rateHz, "logLevel" to c.logLevel)
        else -> mapOf("type" to "resyncNeeded")
    }

    // MARK: - 오류 → 채널

    /** SDK 오류는 E-코드를 그대로 넘긴다 — iOS 와 같은 코드라 앱은 플랫폼을 가리지 않고 분기한다. */
    private fun flutterError(e: Throwable): Triple<String, String, Map<String, Any?>> = when (e) {
        is SdkError -> Triple(
            e.code.code, e.message ?: e.code.code,
            mapOf("kind" to "sdk", "name" to e.javaClass.simpleName.replaceFirstChar { it.lowercase() }),
        )
        is ApiError -> {
            val details = mutableMapOf<String, Any?>(
                "kind" to "api", "name" to e.javaClass.simpleName.replaceFirstChar { it.lowercase() },
            )
            when (e) {
                is ApiError.InvalidKey -> details["detail"] = e.detail
                is ApiError.Forbidden -> details["detail"] = e.detail
                is ApiError.NotFound -> details["detail"] = e.detail
                is ApiError.Unprocessable -> details["detail"] = e.detail
                is ApiError.Decoding -> details["detail"] = e.detail
                is ApiError.Server -> {
                    details["status"] = e.status
                    details["detail"] = e.detail
                }
                else -> Unit
            }
            Triple(e.code.code, e.message ?: e.code.code, details)
        }
        is UnsupportedActivity -> Triple(
            "unsupportedActivity", e.message ?: "", mapOf("kind" to "plugin", "name" to "unsupportedActivity"),
        )
        is BadArgument -> Triple("internal", e.message ?: "", mapOf("kind" to "plugin", "name" to "badArgument"))
        else -> Triple("internal", e.toString(), mapOf("kind" to "plugin", "name" to "unknown"))
    }
}
