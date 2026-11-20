package app.insato.insato

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/**
 * Recording import: decodes an audio file (m4a/AAC, mp3, amr, ogg/opus,
 * flac, 3gp, wav, ...) to interleaved PCM16 with the platform's own
 * MediaExtractor + MediaCodec. See lib/features/import_audio/audio_decoder.dart
 * for the protocol of the MethodChannel "insato/audio_decoder".
 *
 * Every call runs on one background thread (decoding never blocks the UI
 * thread); replies are posted back to the main thread. Dart pulls the PCM
 * chunk by chunk, so nothing is decoded ahead of the consumer.
 */
class AudioDecoderChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "insato/audio_decoder")
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val sessions = ConcurrentHashMap<Int, DecodeSession>()
    private val nextHandle = AtomicInteger(1)

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    /** Releases every open decoder (activity destroyed). */
    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.execute {
            for (s in sessions.values) s.release()
            sessions.clear()
        }
        worker.shutdown()
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(true)
            "open" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("io", "missing path", null)
                    return
                }
                runOnWorker(result) {
                    val session = DecodeSession.open(path)
                    val handle = nextHandle.getAndIncrement()
                    sessions[handle] = session
                    mapOf(
                        "handle" to handle,
                        "sampleRate" to session.sampleRate,
                        "channels" to session.channels,
                        "durationMs" to session.durationMs,
                        "codec" to session.mime,
                        "creationDate" to session.creationDate,
                    )
                }
            }
            "read" -> {
                val handle = call.argument<Int>("handle") ?: -1
                val maxBytes = (call.argument<Int>("maxBytes") ?: DEFAULT_CHUNK)
                    .coerceIn(4096, 4 * 1024 * 1024)
                runOnWorker(result) {
                    val session = sessions[handle]
                        ?: throw DecodeError("decode", "unknown handle $handle")
                    val chunk = session.read(maxBytes)
                    if (chunk == null) {
                        null
                    } else {
                        mapOf(
                            "data" to chunk.data,
                            "sampleRate" to chunk.sampleRate,
                            "channels" to chunk.channels,
                        )
                    }
                }
            }
            "close" -> {
                val handle = call.argument<Int>("handle") ?: -1
                runOnWorker(result) {
                    sessions.remove(handle)?.release()
                    null
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun runOnWorker(result: MethodChannel.Result, block: () -> Any?) {
        try {
            worker.execute {
                try {
                    val value = block()
                    main.post { result.success(value) }
                } catch (e: DecodeError) {
                    main.post { result.error(e.code, e.message, null) }
                } catch (e: Throwable) {
                    main.post { result.error("decode", e.toString(), null) }
                }
            }
        } catch (e: Exception) {
            // Executor shut down (activity destroyed).
            result.error("decode", e.toString(), null)
        }
    }

    companion object {
        const val DEFAULT_CHUNK = 256 * 1024
    }
}

/** A failure with a protocol error code (unsupported / not_found / io / decode). */
class DecodeError(val code: String, message: String) : Exception(message)

/** Decoded PCM16 little-endian, interleaved. */
class PcmChunk(val data: ByteArray, val sampleRate: Int, val channels: Int)

/** One open file: extractor + decoder of its first audio track. */
class DecodeSession private constructor(
    private val extractor: MediaExtractor,
    private val codec: MediaCodec,
    val mime: String,
    var sampleRate: Int,
    var channels: Int,
    val durationMs: Int?,
    val creationDate: String?,
) {
    private var encoding = AudioFormat.ENCODING_PCM_16BIT
    private var inputDone = false
    private var outputDone = false
    private var released = false

    // A format change that arrived while a chunk in the old format was
    // being filled: applied at the start of the next read.
    private var pendingRate = 0
    private var pendingChannels = 0
    private var pendingEncoding = AudioFormat.ENCODING_PCM_16BIT

    companion object {
        private const val TIMEOUT_US = 10_000L

        // About 30 s without any decoder progress means a stuck codec.
        private const val MAX_IDLE_LOOPS = 3000

        fun open(path: String): DecodeSession {
            val file = File(path)
            if (!file.exists()) throw DecodeError("not_found", path)
            if (!file.canRead()) throw DecodeError("io", "not readable")
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(path)
            } catch (e: FileNotFoundException) {
                extractor.release()
                throw DecodeError("not_found", e.toString())
            } catch (e: IOException) {
                // Unknown container (no extractor for it).
                extractor.release()
                throw DecodeError("unsupported", e.toString())
            } catch (e: Exception) {
                extractor.release()
                throw DecodeError("unsupported", e.toString())
            }
            var track = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val m = f.getString(MediaFormat.KEY_MIME) ?: continue
                if (m.startsWith("audio/")) {
                    track = i
                    format = f
                    break
                }
            }
            if (track < 0 || format == null) {
                extractor.release()
                throw DecodeError("unsupported", "no audio track")
            }
            extractor.selectTrack(track)
            val mime = format.getString(MediaFormat.KEY_MIME)!!
            val rate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                0
            }
            val channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else {
                0
            }
            val durationMs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                val us = format.getLong(MediaFormat.KEY_DURATION)
                if (us > 0) (us / 1000).coerceAtMost(Int.MAX_VALUE.toLong()).toInt() else null
            } else {
                null
            }
            val codec: MediaCodec
            try {
                codec = MediaCodec.createDecoderByType(mime)
            } catch (e: Exception) {
                extractor.release()
                throw DecodeError("unsupported", "no decoder for $mime: $e")
            }
            try {
                codec.configure(format, null, null, 0)
                codec.start()
            } catch (e: Exception) {
                codec.release()
                extractor.release()
                throw DecodeError("unsupported", "cannot start decoder for $mime: $e")
            }
            val session = DecodeSession(
                extractor,
                codec,
                mime,
                if (rate > 0) rate else 16000,
                if (channels > 0) channels else 1,
                durationMs,
                creationDateOf(path),
            )
            return session
        }

        /** The container's creation date (raw string, parsed in Dart). */
        private fun creationDateOf(path: String): String? {
            val retriever = MediaMetadataRetriever()
            return try {
                retriever.setDataSource(path)
                retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DATE)
            } catch (e: Exception) {
                null
            } finally {
                try {
                    retriever.release()
                } catch (e: Exception) {
                    // Ignore.
                }
            }
        }
    }

    /**
     * Decodes until about [maxBytes] of PCM16 are ready. Returns null at the
     * end of the stream. A chunk never mixes two formats.
     */
    fun read(maxBytes: Int): PcmChunk? {
        if (released) throw DecodeError("decode", "closed")
        if (pendingRate > 0) {
            sampleRate = pendingRate
            channels = pendingChannels
            encoding = pendingEncoding
            pendingRate = 0
        }
        if (outputDone) return null
        val out = ByteArrayOutputStream(maxBytes + 16384)
        val info = MediaCodec.BufferInfo()
        var idle = 0
        try {
            while (out.size() < maxBytes && !outputDone) {
                var progressed = false
                if (!inputDone) {
                    val inIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (inIndex >= 0) {
                        val buffer = codec.getInputBuffer(inIndex)
                        val size = if (buffer == null) -1 else extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            codec.queueInputBuffer(
                                inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                        progressed = true
                    }
                }
                val outIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
                if (outIndex >= 0) {
                    progressed = true
                    val buffer = codec.getOutputBuffer(outIndex)
                    if (buffer != null && info.size > 0) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        appendPcm16(buffer.slice().order(ByteOrder.nativeOrder()), out)
                    }
                    codec.releaseOutputBuffer(outIndex, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    progressed = true
                    val f = codec.outputFormat
                    val newRate = if (f.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    } else {
                        sampleRate
                    }
                    val newChannels = if (f.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                        f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    } else {
                        channels
                    }
                    val newEncoding =
                        if (Build.VERSION.SDK_INT >= 24 && f.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            f.getInteger(MediaFormat.KEY_PCM_ENCODING)
                        } else {
                            AudioFormat.ENCODING_PCM_16BIT
                        }
                    val changed = newRate != sampleRate || newChannels != channels
                    if (out.size() > 0 && changed) {
                        pendingRate = newRate
                        pendingChannels = newChannels
                        pendingEncoding = newEncoding
                        break
                    }
                    sampleRate = newRate
                    channels = newChannels
                    encoding = newEncoding
                }
                if (progressed) {
                    idle = 0
                } else if (++idle > MAX_IDLE_LOOPS) {
                    throw DecodeError("decode", "decoder stalled")
                }
            }
        } catch (e: DecodeError) {
            throw e
        } catch (e: MediaCodec.CodecException) {
            throw DecodeError("decode", e.toString())
        } catch (e: IllegalStateException) {
            throw DecodeError("decode", e.toString())
        }
        if (out.size() == 0 && outputDone) return null
        return PcmChunk(out.toByteArray(), sampleRate, channels)
    }

    /** Appends [src] (decoder output in [encoding]) as PCM16 LE to [out]. */
    private fun appendPcm16(src: ByteBuffer, out: ByteArrayOutputStream) {
        when (encoding) {
            AudioFormat.ENCODING_PCM_FLOAT -> {
                val n = src.remaining() / 4
                val bytes = ByteArray(n * 2)
                for (i in 0 until n) {
                    val v = src.getFloat()
                    val clamped = if (v.isNaN()) 0f else v.coerceIn(-1f, 1f)
                    val s = (clamped * 32767f).toInt()
                    bytes[2 * i] = (s and 0xFF).toByte()
                    bytes[2 * i + 1] = ((s shr 8) and 0xFF).toByte()
                }
                out.write(bytes, 0, bytes.size)
            }
            AudioFormat.ENCODING_PCM_8BIT -> {
                val n = src.remaining()
                val bytes = ByteArray(n * 2)
                for (i in 0 until n) {
                    val s = ((src.get().toInt() and 0xFF) - 128) shl 8
                    bytes[2 * i] = (s and 0xFF).toByte()
                    bytes[2 * i + 1] = ((s shr 8) and 0xFF).toByte()
                }
                out.write(bytes, 0, bytes.size)
            }
            ENCODING_PCM_24BIT_PACKED -> {
                val n = src.remaining() / 3
                val bytes = ByteArray(n * 2)
                for (i in 0 until n) {
                    src.get() // Least significant byte dropped.
                    bytes[2 * i] = src.get()
                    bytes[2 * i + 1] = src.get()
                }
                out.write(bytes, 0, bytes.size)
            }
            ENCODING_PCM_32BIT -> {
                val n = src.remaining() / 4
                val bytes = ByteArray(n * 2)
                for (i in 0 until n) {
                    val s = src.getInt() shr 16
                    bytes[2 * i] = (s and 0xFF).toByte()
                    bytes[2 * i + 1] = ((s shr 8) and 0xFF).toByte()
                }
                out.write(bytes, 0, bytes.size)
            }
            else -> {
                // PCM16 in native (little-endian) order.
                val n = src.remaining() / 2
                val bytes = ByteArray(n * 2)
                for (i in 0 until n) {
                    val s = src.getShort().toInt()
                    bytes[2 * i] = (s and 0xFF).toByte()
                    bytes[2 * i + 1] = ((s shr 8) and 0xFF).toByte()
                }
                out.write(bytes, 0, bytes.size)
            }
        }
    }

    /** Releases the decoder and the extractor. Idempotent. */
    fun release() {
        if (released) return
        released = true
        try {
            codec.stop()
        } catch (e: Exception) {
            // Not started or already failed.
        }
        try {
            codec.release()
        } catch (e: Exception) {
            // Ignore.
        }
        try {
            extractor.release()
        } catch (e: Exception) {
            // Ignore.
        }
    }
}

// AudioFormat.ENCODING_PCM_24BIT_PACKED / ENCODING_PCM_32BIT (API 31); the
// values are stable, so they are spelled out for older compile targets.
private const val ENCODING_PCM_24BIT_PACKED = 21
private const val ENCODING_PCM_32BIT = 22
