package app.insato.insato

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Recording import: audio files shared to Insato by other apps (call
 * recorder, voice recorder, file manager, WhatsApp, ...) through
 * ACTION_SEND / ACTION_SEND_MULTIPLE / ACTION_VIEW (intent filters in
 * AndroidManifest.xml). content:// URIs are not file paths Dart can read,
 * so each file is copied into the app's cache ("shared_audio") on a
 * background thread and queued; Dart pulls the queue through the
 * MethodChannel "insato/shared_audio" (see
 * lib/features/import_audio/shared_audio_inbox.dart):
 *
 *   takePending -> [{path, name}] or [{name, error: "too_large" | "copy_failed"}]
 *   onShared (to Dart) -> new entries were queued
 */
class SharedAudioChannel(context: Context, messenger: BinaryMessenger) {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "insato/shared_audio")
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    // Main thread only.
    private val pending = ArrayList<Map<String, Any?>>()

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "takePending") {
                val copy = ArrayList(pending)
                pending.clear()
                result.success(copy)
            } else {
                result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    /** Queues the audio files of [intent], if it shares any. */
    fun handle(intent: Intent?) {
        if (intent == null || intent.getBooleanExtra(HANDLED_EXTRA, false)) return
        val uris = urisOf(intent)
        if (uris.isEmpty()) return
        // Never import the same share twice (activity re-delivery).
        intent.putExtra(HANDLED_EXTRA, true)
        try {
            worker.execute {
                val entries = uris.take(MAX_FILES).map { copy(it) }
                main.post {
                    pending.addAll(entries)
                    channel.invokeMethod("onShared", null)
                }
            }
        } catch (e: Exception) {
            // Executor shut down: the activity is going away.
        }
    }

    private fun urisOf(intent: Intent): List<Uri> {
        val out = ArrayList<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
                }
                if (uri != null) out.add(uri)
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val list = if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                }
                if (list != null) out.addAll(list)
            }
            Intent.ACTION_VIEW -> intent.data?.let { out.add(it) }
            else -> return out
        }
        if (out.isEmpty()) {
            val clip = intent.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) {
                    clip.getItemAt(i).uri?.let { out.add(it) }
                }
            }
        }
        return out.filter { it.scheme == "content" || it.scheme == "file" }
    }

    /** Copies [uri] into the cache; the entry describes the copy or the error. */
    private fun copy(uri: Uri): Map<String, Any?> {
        var name = "audio"
        var size = -1L
        try {
            appContext.contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val n = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (n >= 0 && !c.isNull(n)) name = c.getString(n)
                    val s = c.getColumnIndex(OpenableColumns.SIZE)
                    if (s >= 0 && !c.isNull(s)) size = c.getLong(s)
                }
            }
        } catch (e: Exception) {
            // Name and size stay unknown.
        }
        if (name == "audio") uri.lastPathSegment?.let { if (it.isNotBlank()) name = it }
        if (size > MAX_BYTES) return mapOf("name" to name, "error" to "too_large")
        val dir = File(appContext.cacheDir, "shared_audio")
        dir.mkdirs()
        val safe = name.replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001f]"), "_").take(120)
        val target = File(dir, "${System.currentTimeMillis()}_$safe")
        return try {
            var total = 0L
            appContext.contentResolver.openInputStream(uri).use { input ->
                if (input == null) throw IllegalStateException("no stream")
                target.outputStream().use { output ->
                    val buffer = ByteArray(256 * 1024)
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        total += n
                        if (total > MAX_BYTES) throw TooLarge()
                        output.write(buffer, 0, n)
                    }
                }
            }
            mapOf("path" to target.absolutePath, "name" to name)
        } catch (e: TooLarge) {
            target.delete()
            mapOf("name" to name, "error" to "too_large")
        } catch (e: Exception) {
            target.delete()
            mapOf("name" to name, "error" to "copy_failed")
        }
    }

    private class TooLarge : Exception()

    companion object {
        private const val HANDLED_EXTRA = "app.insato.insato.SHARED_AUDIO_HANDLED"

        // Same limit as kMaxImportBytes in audio_formats.dart (2 GiB).
        private const val MAX_BYTES = 2L * 1024 * 1024 * 1024
        private const val MAX_FILES = 5
    }
}
