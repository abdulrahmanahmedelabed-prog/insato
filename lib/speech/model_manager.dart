// Downloads, verifies, extracts and tracks on-device models.
//
// Layout below [ModelManager.baseDir]:
//
//   <id>/                      installed model (atomic: renamed from staging)
//   <id>/.insato-model.json     install marker
//   .downloads/<id>.part       partial download (resumable)
//   .downloads/<id>.part.json  resume metadata (url, validator, total size)
//   .staging/<id>-<ts>/        extraction / verification area
//
// All failures surface as [ModelException] with an Arabic message.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/errors.dart';
import '../core/interfaces.dart';
import 'model_catalog.dart';

/// Thrown (as the error of [ModelManager.download]) when a download was
/// cancelled with [ModelManager.cancel] or [ModelManager.delete].
class ModelDownloadCancelledException extends ModelException {
  /// Creates the exception.
  const ModelDownloadCancelledException()
      : super('تم إلغاء تنزيل النموذج.');
}

/// Name of the marker file written into every installed model directory.
const String kModelMarkerFile = '.insato-model.json';

/// Manages the lifecycle of the models in [ModelCatalog] (or a custom
/// catalog): status tracking, resumable downloads with retries and
/// cancellation, background extraction, atomic installation and
/// verification.
class ModelManager {
  /// Creates a manager storing models below [baseDir].
  ///
  /// [client] is used for downloads (an internal client is created and owned
  /// when omitted). [maxAttempts] is the number of consecutive attempts
  /// without progress before giving up. [sleep] is injectable for tests.
  ModelManager(
    this.baseDir, {
    http.Client? client,
    List<ModelSpec>? catalog,
    this.maxAttempts = 5,
    this.retryBaseDelay = const Duration(seconds: 2),
    this.connectTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 60),
    Future<void> Function(Duration)? sleep,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _catalog = List.unmodifiable(catalog ?? ModelCatalog.all),
        _sleep = sleep ?? Future<void>.delayed {
    for (final m in _catalog) {
      _states[m.id] = const ModelState(ModelStatus.notDownloaded);
    }
  }

  /// Root directory of all model files.
  final String baseDir;

  /// Consecutive failed attempts (without any downloaded bytes) tolerated
  /// before a download fails.
  final int maxAttempts;

  /// First retry delay; doubles on each consecutive failure (capped at 60 s).
  final Duration retryBaseDelay;

  /// Timeout for receiving the response headers.
  final Duration connectTimeout;

  /// Maximum time without receiving any byte while streaming.
  final Duration idleTimeout;

  final http.Client _client;
  final bool _ownsClient;
  final List<ModelSpec> _catalog;
  final Future<void> Function(Duration) _sleep;

  final Map<String, ModelState> _states = {};
  final Map<String, Future<void>> _active = {};
  final Map<String, _CancelToken> _tokens = {};
  final StreamController<Map<String, ModelState>> _controller =
      StreamController<Map<String, ModelState>>.broadcast();
  bool _disposed = false;

  /// Models managed by this instance.
  List<ModelSpec> get catalog => _catalog;

  /// Snapshot of every model's state, keyed by model id.
  Map<String, ModelState> get states => Map.unmodifiable(_states);

  /// Emits the current snapshot immediately, then every change.
  Stream<Map<String, ModelState>> get statesStream async* {
    yield states;
    yield* _controller.stream;
  }

  /// Current state of [modelId].
  ModelState stateOf(String modelId) {
    _spec(modelId);
    return _states[modelId]!;
  }

  /// True when [modelId] is installed and verified.
  bool isReady(String modelId) =>
      stateOf(modelId).status == ModelStatus.ready;

  /// True while [modelId] is being downloaded / installed.
  bool isDownloading(String modelId) => _active.containsKey(modelId);

  /// Directory holding the installed files of [modelId].
  String modelDir(String modelId) => p.join(baseDir, modelId);

  String get _downloadsDir => p.join(baseDir, '.downloads');
  String get _stagingDir => p.join(baseDir, '.staging');
  String _partPath(String id) => p.join(_downloadsDir, '$id.part');
  String _metaPath(String id) => p.join(_downloadsDir, '$id.part.json');

  ModelSpec _spec(String id) {
    for (final m in _catalog) {
      if (m.id == id) return m;
    }
    throw ModelException('النموذج المطلوب غير معروف.',
        debugDetails: 'unknown model id: $id');
  }

  void _set(String id, ModelState s) {
    _states[id] = s;
    if (!_disposed) _controller.add(states);
  }

  // -------------------------------------------------------------------------
  // Status
  // -------------------------------------------------------------------------

  /// Re-scans the disk and updates every model's state (models currently
  /// downloading are left untouched). Also removes stale staging data.
  Future<void> refresh() async {
    await _cleanupStaging();
    for (final spec in _catalog) {
      if (_active.containsKey(spec.id)) continue;
      _set(spec.id, await _diskState(spec));
    }
  }

  Future<ModelState> _diskState(ModelSpec spec) async {
    final dir = Directory(modelDir(spec.id));
    if (await dir.exists()) {
      final marker = File(p.join(dir.path, kModelMarkerFile));
      final files = await _listFiles(dir.path);
      if (await marker.exists() &&
          missingRequiredFiles(spec, files).isEmpty &&
          resolveModelFiles(spec, files) != null) {
        return const ModelState(ModelStatus.ready, progress: 1);
      }
      return const ModelState(
        ModelStatus.failed,
        error: 'ملفات النموذج غير مكتملة أو تالفة. يُرجى حذفه وإعادة تنزيله.',
      );
    }
    final part = File(_partPath(spec.id));
    if (await part.exists()) {
      final have = await part.length();
      final meta = await _readMeta(spec.id);
      final total = meta?.total ?? spec.approxSizeMb * 1024 * 1024;
      return ModelState(
        ModelStatus.notDownloaded,
        progress: total > 0 ? (have / total).clamp(0.0, 1.0) : 0,
      );
    }
    return const ModelState(ModelStatus.notDownloaded);
  }

  static Future<List<String>> _listFiles(String dir) =>
      Isolate.run(() => listModelFilesSync(dir));

  // -------------------------------------------------------------------------
  // Download / install
  // -------------------------------------------------------------------------

  /// Downloads (resuming a previous partial download when possible),
  /// extracts, verifies and installs [modelId].
  ///
  /// Completes when the model is ready. A second call while a download is in
  /// progress returns the same future. Completes immediately when the model
  /// is already installed. Throws [ModelDownloadCancelledException] when
  /// cancelled and [ModelException] on failure.
  Future<void> download(String modelId) {
    final spec = _spec(modelId);
    if (_disposed) {
      return Future.error(const ModelException('مدير النماذج مُغلق.'));
    }
    final running = _active[modelId];
    if (running != null) return running;
    final token = _CancelToken();
    _tokens[modelId] = token;
    final f = _install(spec, token).whenComplete(() {
      _active.remove(modelId);
      _tokens.remove(modelId);
    });
    _active[modelId] = f;
    return f;
  }

  /// Cancels an in-flight download of [modelId] (no-op otherwise). The
  /// partial file is kept so the download can be resumed later.
  void cancel(String modelId) => _tokens[modelId]?.cancel();

  Future<void> _install(ModelSpec spec, _CancelToken token) async {
    final current = await _diskState(spec);
    if (current.status == ModelStatus.ready) {
      _set(spec.id, current);
      return;
    }
    _set(spec.id, ModelState(ModelStatus.downloading,
        progress: current.progress));
    String? staging;
    try {
      await Directory(_downloadsDir).create(recursive: true);
      await _downloadWithRetries(spec, token);
      token.throwIfCancelled();

      staging = p.join(_stagingDir,
          '${spec.id}-${DateTime.now().microsecondsSinceEpoch}');
      await Directory(staging).create(recursive: true);
      final part = _partPath(spec.id);
      if (spec.archive) {
        try {
          await _extractInBackground(part, staging, spec.extractFiles);
        } on ModelException {
          rethrow;
        } on FileSystemException {
          rethrow;
        } catch (e) {
          // Corrupt archive: discard it so the next attempt starts fresh.
          await _deleteIfExists(File(part));
          await _deleteIfExists(File(_metaPath(spec.id)));
          throw ModelException(
            'ملف النموذج المُنزَّل تالف. يُرجى إعادة المحاولة.',
            debugDetails: 'extract ${spec.id}: $e',
            cause: e,
          );
        }
      } else {
        await File(part).rename(p.join(staging, spec.fileName));
      }
      token.throwIfCancelled();

      final files = await _listFiles(staging);
      final missing = missingRequiredFiles(spec, files);
      if (missing.isNotEmpty || resolveModelFiles(spec, files) == null) {
        await _deleteIfExists(File(part));
        await _deleteIfExists(File(_metaPath(spec.id)));
        throw ModelException(
          'ملفات النموذج غير مكتملة بعد التنزيل. يُرجى إعادة المحاولة.',
          debugDetails: 'missing ${missing.join(', ')} in ${spec.id}',
        );
      }
      await File(p.join(staging, kModelMarkerFile)).writeAsString(
        jsonEncode({
          'id': spec.id,
          'url': spec.url,
          'installedAt': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
      await _atomicReplace(staging, modelDir(spec.id));
      staging = null;
      await _deleteIfExists(File(part));
      await _deleteIfExists(File(_metaPath(spec.id)));
      _set(spec.id, const ModelState(ModelStatus.ready, progress: 1));
    } on ModelDownloadCancelledException {
      _set(spec.id, await _diskState(spec));
      rethrow;
    } on ModelException catch (e) {
      _set(spec.id, ModelState(ModelStatus.failed, error: e.messageAr));
      rethrow;
    } on FileSystemException catch (e) {
      const msg = 'تعذّر حفظ ملفات النموذج. تأكد من توفر مساحة تخزين كافية.';
      _set(spec.id, const ModelState(ModelStatus.failed, error: msg));
      throw ModelException(msg, debugDetails: e.toString(), cause: e);
    } finally {
      if (staging != null) await _deleteDirIfExists(Directory(staging));
    }
  }

  Future<void> _downloadWithRetries(ModelSpec spec, _CancelToken token) async {
    var failures = 0;
    while (true) {
      token.throwIfCancelled();
      final before = await _partLength(spec.id);
      try {
        await _downloadOnce(spec, token);
        return;
      } on ModelException {
        rethrow;
      } on FileSystemException {
        rethrow;
      } catch (e) {
        if (token.cancelled) throw const ModelDownloadCancelledException();
        final after = await _partLength(spec.id);
        failures = after > before ? 1 : failures + 1;
        if (failures >= maxAttempts) {
          throw ModelException(
            'تعذّر تنزيل النموذج. تحقق من الاتصال بالإنترنت ثم أعد المحاولة.',
            debugDetails: 'download ${spec.id}: $e',
            cause: e,
          );
        }
        final delayMs = math.min(
          retryBaseDelay.inMilliseconds * (1 << (failures - 1)),
          60000,
        );
        await Future.any<void>([
          _sleep(Duration(milliseconds: delayMs)),
          token.aborted,
        ]);
      }
    }
  }

  Future<int> _partLength(String id) async {
    final f = File(_partPath(id));
    return await f.exists() ? await f.length() : 0;
  }

  Future<void> _downloadOnce(ModelSpec spec, _CancelToken token) async {
    final partFile = File(_partPath(spec.id));
    var meta = await _readMeta(spec.id);
    var existing = await partFile.exists() ? await partFile.length() : 0;
    if (existing > 0 && (meta == null || meta.url != spec.url)) {
      await partFile.delete();
      existing = 0;
      meta = null;
    }
    if (existing > 0 && meta?.total != null && existing == meta!.total) {
      return; // Already complete (e.g. extraction failed previously).
    }

    final req = http.AbortableRequest('GET', Uri.parse(spec.url),
        abortTrigger: token.aborted);
    req.headers['Accept-Encoding'] = 'identity';
    if (existing > 0) {
      req.headers['Range'] = 'bytes=$existing-';
      final validator = meta?.validator;
      if (validator != null) req.headers['If-Range'] = validator;
    }

    final resp = await _client.send(req).timeout(connectTimeout);
    final status = resp.statusCode;

    int offset;
    int? total;
    FileMode mode;
    if (status == 206 && existing > 0) {
      final range = parseContentRange(resp.headers['content-range']);
      if (range == null || range.start != existing) {
        await _drain(resp);
        await partFile.delete();
        throw const _RetryableError('unexpected content-range');
      }
      offset = existing;
      total = range.total ??
          (resp.contentLength != null ? existing + resp.contentLength! : null);
      mode = FileMode.append;
    } else if (status == 200 || status == 206) {
      offset = 0;
      total = resp.contentLength;
      mode = FileMode.write;
      meta = _DownloadMeta(
        url: spec.url,
        validator: resp.headers['etag'] ?? resp.headers['last-modified'],
        total: total,
      );
      await _writeMeta(spec.id, meta);
    } else if (status == 416 && existing > 0) {
      await _drain(resp);
      final range = parseContentRange(resp.headers['content-range']);
      if (range?.total != null && range!.total == existing) {
        await _writeMeta(
            spec.id,
            _DownloadMeta(
                url: spec.url, validator: meta?.validator, total: existing));
        return;
      }
      await partFile.delete();
      throw const _RetryableError('range not satisfiable');
    } else if (status == 408 || status == 429 || status >= 500) {
      await _drain(resp);
      throw _RetryableError('HTTP $status');
    } else {
      await _drain(resp);
      throw ModelException(
        'تعذّر تنزيل النموذج من الخادم (رمز $status).',
        debugDetails: 'GET ${spec.url} -> $status',
      );
    }
    if (total != null && meta?.total != total) {
      meta = _DownloadMeta(
          url: spec.url, validator: meta?.validator, total: total);
      await _writeMeta(spec.id, meta);
    }

    final expectedTotal = total ?? spec.approxSizeMb * 1024 * 1024;
    final sink = partFile.openWrite(mode: mode);
    var received = offset;
    var lastEmit = DateTime.now();
    var lastProgress = -1.0;
    try {
      await for (final chunk in resp.stream.timeout(idleTimeout)) {
        if (token.cancelled) break;
        sink.add(chunk);
        received += chunk.length;
        final progress = expectedTotal > 0
            ? (received / expectedTotal).clamp(0.0, 1.0)
            : 0.0;
        final now = DateTime.now();
        if (progress - lastProgress >= 0.005 ||
            now.difference(lastEmit).inMilliseconds >= 250) {
          lastEmit = now;
          lastProgress = progress;
          _set(spec.id,
              ModelState(ModelStatus.downloading, progress: progress));
        }
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    if (token.cancelled) throw const ModelDownloadCancelledException();
    if (total != null && received != total) {
      if (received > total) await partFile.delete();
      throw _RetryableError('incomplete download: $received/$total');
    }
    if (received == 0) {
      throw const _RetryableError('empty response');
    }
    if (total == null) {
      await _writeMeta(spec.id,
          _DownloadMeta(url: spec.url, validator: meta?.validator, total: received));
    }
    _set(spec.id, const ModelState(ModelStatus.downloading, progress: 1));
  }

  static Future<void> _drain(http.StreamedResponse r) async {
    try {
      await r.stream.drain<void>();
    } catch (_) {
      // Ignore: the response is discarded anyway.
    }
  }

  Future<_DownloadMeta?> _readMeta(String id) async {
    final f = File(_metaPath(id));
    if (!await f.exists()) return null;
    try {
      final j = jsonDecode(await f.readAsString());
      if (j is! Map) return null;
      return _DownloadMeta(
        url: j['url'] as String? ?? '',
        validator: j['validator'] as String?,
        total: (j['total'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeMeta(String id, _DownloadMeta m) async {
    await File(_metaPath(id)).writeAsString(
      jsonEncode({'url': m.url, 'validator': m.validator, 'total': m.total}),
      flush: true,
    );
  }

  static Future<void> _extractInBackground(
    String archivePath,
    String outDir,
    List<String>? include,
  ) {
    return Isolate.run(
        () => extractTarBz2Sync(archivePath, outDir, includeGlobs: include));
  }

  Future<void> _atomicReplace(String staging, String target) async {
    final targetDir = Directory(target);
    String? trash;
    if (await targetDir.exists()) {
      trash = '$target.old-${DateTime.now().microsecondsSinceEpoch}';
      await targetDir.rename(trash);
    }
    try {
      await Directory(staging).rename(target);
    } catch (_) {
      if (trash != null && !await targetDir.exists()) {
        await Directory(trash).rename(target);
        trash = null;
      }
      rethrow;
    } finally {
      if (trash != null) await _deleteDirIfExists(Directory(trash));
    }
  }

  Future<void> _cleanupStaging() async {
    if (_active.isNotEmpty) return;
    await _deleteDirIfExists(Directory(_stagingDir));
    final base = Directory(baseDir);
    if (!await base.exists()) return;
    await for (final e in base.list(followLinks: false)) {
      if (e is Directory && p.basename(e.path).contains('.old-')) {
        await _deleteDirIfExists(e);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Delete / resolve
  // -------------------------------------------------------------------------

  /// Deletes [modelId] (installed files and any partial download). Cancels
  /// a running download first.
  Future<void> delete(String modelId) async {
    final spec = _spec(modelId);
    final running = _active[modelId];
    if (running != null) {
      cancel(modelId);
      try {
        await running;
      } catch (_) {
        // Expected: cancelled.
      }
    }
    try {
      await _deleteDirIfExists(Directory(modelDir(spec.id)));
      await _deleteIfExists(File(_partPath(spec.id)));
      await _deleteIfExists(File(_metaPath(spec.id)));
    } on FileSystemException catch (e) {
      throw ModelException('تعذّر حذف ملفات النموذج.',
          debugDetails: e.toString(), cause: e);
    }
    _set(spec.id, const ModelState(ModelStatus.notDownloaded));
  }

  /// Absolute file locations of the installed [modelId]: a
  /// [WhisperModelPaths] for ASR models, a [SingleFileModelPath] otherwise.
  /// Throws [ModelException] when the model is not installed or incomplete.
  Future<ResolvedModel> resolvedPaths(String modelId) async {
    final spec = _spec(modelId);
    final dir = modelDir(spec.id);
    final marker = File(p.join(dir, kModelMarkerFile));
    final files = await _listFiles(dir);
    final resolved =
        await marker.exists() ? resolveModelFiles(spec, files) : null;
    if (resolved == null) {
      throw ModelException(
        'النموذج «${spec.displayNameAr}» غير مُنزَّل أو ملفاته غير مكتملة.',
        debugDetails: 'cannot resolve ${spec.id} in $dir',
      );
    }
    return resolved;
  }

  /// Like [resolvedPaths] for an ASR (Whisper) model.
  Future<WhisperModelPaths> whisperPaths(String modelId) async {
    final r = await resolvedPaths(modelId);
    if (r is WhisperModelPaths) return r;
    throw ModelException('النموذج المحدد ليس نموذج تفريغ كلام.',
        debugDetails: '$modelId is not an ASR model');
  }

  /// Like [resolvedPaths] for a single-file model (VAD, speaker).
  Future<String> filePath(String modelId) async {
    final r = await resolvedPaths(modelId);
    if (r is SingleFileModelPath) return r.path;
    throw ModelException('النموذج المحدد ليس ملفاً واحداً.',
        debugDetails: '$modelId is not a single-file model');
  }

  /// Cancels running downloads and releases resources.
  Future<void> dispose() async {
    if (_disposed) return;
    for (final t in _tokens.values) {
      t.cancel();
    }
    final running = _active.values.toList();
    for (final f in running) {
      try {
        await f;
      } catch (_) {
        // Cancelled.
      }
    }
    _disposed = true;
    await _controller.close();
    if (_ownsClient) _client.close();
  }

  static Future<void> _deleteIfExists(File f) async {
    if (await f.exists()) await f.delete();
  }

  static Future<void> _deleteDirIfExists(Directory d) async {
    if (await d.exists()) await d.delete(recursive: true);
  }
}

// ---------------------------------------------------------------------------
// Helpers (public where unit-tested).
// ---------------------------------------------------------------------------

/// Parsed `Content-Range: bytes <start>-<end>/<total|*>` header (also the
/// `bytes */<total>` form of a 416 response, where [start]/[end] are -1).
class ContentRange {
  /// Creates a parsed range.
  const ContentRange(this.start, this.end, this.total);

  /// First byte position (-1 for the unsatisfied form).
  final int start;

  /// Last byte position, inclusive (-1 for the unsatisfied form).
  final int end;

  /// Complete length, or null when unknown (`*`).
  final int? total;
}

/// Parses a `Content-Range` header value; null when absent or malformed.
ContentRange? parseContentRange(String? header) {
  if (header == null) return null;
  final m = RegExp(r'^\s*bytes\s+(?:(\d+)-(\d+)|\*)/(\d+|\*)\s*$',
          caseSensitive: false)
      .firstMatch(header);
  if (m == null) return null;
  final total = m.group(3) == '*' ? null : int.tryParse(m.group(3)!);
  if (m.group(1) == null) {
    return total == null ? null : ContentRange(-1, -1, total);
  }
  final start = int.parse(m.group(1)!);
  final end = int.parse(m.group(2)!);
  if (end < start) return null;
  return ContentRange(start, end, total);
}

/// Normalises a tar entry name to a safe relative path, or null when the
/// entry would escape the output directory (absolute path, drive letter,
/// `..` segment) or is empty.
String? safeArchiveEntryPath(String name) {
  final unified = name.replaceAll('\\', '/');
  if (unified.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(unified)) {
    return null;
  }
  final parts = <String>[];
  for (final seg in unified.split('/')) {
    if (seg.isEmpty || seg == '.') continue;
    if (seg == '..') return null;
    parts.add(seg);
  }
  if (parts.isEmpty) return null;
  return p.joinAll(parts);
}

/// Extracts the regular files of the `.tar.bz2` at [archivePath] into
/// [outDir], streaming (bounded memory, suitable for >1 GB archives).
///
/// Only entries whose basename matches one of [includeGlobs] are written
/// (all when null). Links and unsafe paths are skipped. Throws
/// [ArchiveException] for a corrupt or truncated archive. Returns the
/// relative paths written. Synchronous: run it in a background isolate.
List<String> extractTarBz2Sync(
  String archivePath,
  String outDir, {
  List<String>? includeGlobs,
}) {
  final written = <String>[];
  final input = InputFileStream(archivePath);
  try {
    final tar = BZip2Decoder().decodeLazy(input, verify: true);
    TarDecoder().decodeStream(
      tar,
      verify: true,
      throwOnError: true,
      keepEntries: false,
      callback: (entry) {
        if (!entry.isFile || entry.isSymbolicLink) return;
        final rel = safeArchiveEntryPath(entry.name);
        if (rel == null) return;
        if (includeGlobs != null &&
            !includeGlobs.any((g) => matchesGlob(rel, g))) {
          return;
        }
        final dest = p.join(outDir, rel);
        Directory(p.dirname(dest)).createSync(recursive: true);
        final out = OutputFileStream(dest);
        try {
          entry.writeContent(out);
        } finally {
          out.closeSync();
        }
        final len = File(dest).lengthSync();
        if (len != entry.size) {
          File(dest).deleteSync();
          throw ArchiveException(
              'Truncated entry ${entry.name}: $len of ${entry.size} bytes');
        }
        written.add(rel);
      },
    );
  } finally {
    input.closeSync();
  }
  return written;
}

class _DownloadMeta {
  const _DownloadMeta({required this.url, this.validator, this.total});
  final String url;
  final String? validator;
  final int? total;
}

class _RetryableError implements Exception {
  const _RetryableError(this.message);
  final String message;
  @override
  String toString() => 'RetryableError: $message';
}

class _CancelToken {
  final Completer<void> _abort = Completer<void>();
  bool get cancelled => _abort.isCompleted;
  Future<void> get aborted => _abort.future;

  void cancel() {
    if (!_abort.isCompleted) _abort.complete();
  }

  void throwIfCancelled() {
    if (cancelled) throw const ModelDownloadCancelledException();
  }
}
