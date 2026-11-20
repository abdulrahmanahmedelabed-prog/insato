package app.insato.insato

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var openFileChannel: MethodChannel? = null

    /** Copy of the package the app was launched with, until Dart asks. */
    private var pendingPackage: String? = null

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

        // Meeting packages (.insato) opened or shared from other apps
        // (lib/features/meeting_package/package_providers.dart): the content
        // is copied into the app cache and its path handed to Dart.
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "insato/open_file")
        channel.setMethodCallHandler { call, result ->
            if (call.method == "initial") {
                result.success(pendingPackage)
                pendingPackage = null
            } else {
                result.notImplemented()
            }
        }
        openFileChannel = channel
        if (pendingPackage == null) pendingPackage = copyIncoming(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val path = copyIncoming(intent) ?: return
        val channel = openFileChannel
        if (channel == null) {
            pendingPackage = path
        } else {
            channel.invokeMethod("opened", path)
        }
    }

    /** Copies the file of a VIEW / SEND intent into the cache; null if none. */
    private fun copyIncoming(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            else -> null
        }
        if (uri == null) return null
        // Handled once: a configuration change must not import it again.
        intent.action = Intent.ACTION_MAIN
        return try {
            val dir = File(cacheDir, "incoming").apply { mkdirs() }
            val name = displayName(uri)
                ?.replace(Regex("[\\\\/:*?\"<>|]"), "_")
                ?.takeIf { it.isNotBlank() }
                ?: "package.insato"
            val target = File(dir, "${System.currentTimeMillis()}-$name")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            target.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
        } catch (e: Exception) {
            null
        }
    }
}
