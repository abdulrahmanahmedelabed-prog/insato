package app.insato.insato

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Recording import (lib/features/import_audio/): platform audio decoder
    // and files shared to the app by other apps.
    private var audioDecoder: AudioDecoderChannel? = null
    private var sharedAudio: SharedAudioChannel? = null
    private var restored = false

    override fun onCreate(savedInstanceState: Bundle?) {
        // A re-created activity carries the intent it was started with; a
        // share handled before must not be imported again.
        restored = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // v1.2 C: a guest device reports its battery to the meeting host
        // (lib/features/multi_device/battery.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "insato/battery")
            .setMethodCallHandler { call, result ->
                if (call.method != "read") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val manager = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                    val level = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    // Sticky broadcast: no receiver is registered.
                    val status = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        ?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                    val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                        status == BatteryManager.BATTERY_STATUS_FULL
                    result.success(
                        mapOf(
                            "level" to (if (level in 0..100) level else null),
                            "charging" to (if (status == -1) null else charging),
                        ),
                    )
                } catch (e: Exception) {
                    result.success(mapOf<String, Any?>())
                }
            }

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        audioDecoder = AudioDecoderChannel(messenger)
        val shared = SharedAudioChannel(this, messenger)
        sharedAudio = shared
        val launchedFromHistory =
            ((intent?.flags ?: 0) and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0
        if (!restored && !launchedFromHistory) shared.handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedAudio?.handle(intent)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audioDecoder?.dispose()
        audioDecoder = null
        sharedAudio?.dispose()
        sharedAudio = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
