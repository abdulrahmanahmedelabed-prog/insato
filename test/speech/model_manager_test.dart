import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:insato/core/errors.dart';
import 'package:insato/core/interfaces.dart';
import 'package:insato/speech/model_catalog.dart';
import 'package:insato/speech/model_manager.dart';
import 'package:path/path.dart' as p;

const _single = ModelSpec(
  id: 'test-vad',
  displayNameAr: 'اختبار',
  descriptionAr: 'اختبار',
  kind: ModelKind.vad,
  url: 'https://example.com/models/silero_vad.onnx',
  approxSizeMb: 1,
  archive: false,
  requiredFiles: ['*.onnx'],
);

const _whisper = ModelSpec(
  id: 'test-whisper',
  displayNameAr: 'اختبار',
  descriptionAr: 'اختبار',
  kind: ModelKind.asr,
  url: 'https://example.com/models/sherpa-onnx-whisper-tiny.tar.bz2',
  approxSizeMb: 1,
  archive: true,
  requiredFiles: ['*-encoder*.onnx', '*-decoder*.onnx', '*-tokens.txt'],
  extractFiles: ['*-encoder.int8.onnx', '*-decoder.int8.onnx', '*-tokens.txt'],
);

Uint8List _bytes(int n, [int seed = 0]) =>
    Uint8List.fromList(List.generate(n, (i) => (i * 7 + seed) & 0xff));

Uint8List _tarBz2(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach((name, data) => archive.add(ArchiveFile(name, data.length, data)));
  final tar = TarEncoder().encodeBytes(archive);
  return BZip2Encoder().encodeBytes(tar);
}

Uint8List _whisperArchive() => _tarBz2({
      'sherpa-onnx-whisper-tiny/tiny-encoder.int8.onnx': _bytes(3000, 1),
      'sherpa-onnx-whisper-tiny/tiny-encoder.onnx': _bytes(5000, 2),
      'sherpa-onnx-whisper-tiny/tiny-decoder.int8.onnx': _bytes(2000, 3),
      'sherpa-onnx-whisper-tiny/tiny-decoder.onnx': _bytes(4000, 4),
      'sherpa-onnx-whisper-tiny/tiny-tokens.txt': utf8.encode('a 0\nb 1\n'),
      'sherpa-onnx-whisper-tiny/README.md': utf8.encode('readme'),
    });

/// Serves [body] with Range support; [onRequest] can override responses.
MockClient _server(
  Uint8List body, {
  List<http.BaseRequest>? log,
  FutureOr<http.StreamedResponse?> Function(http.BaseRequest r, int n)?
      onRequest,
  int chunk = 1024,
}) {
  var n = 0;
  return MockClient.streaming((req, _) async {
    log?.add(req);
    n++;
    final override = await onRequest?.call(req, n);
    if (override != null) return override;
    final range = req.headers['Range'];
    var start = 0;
    var status = 200;
    final headers = <String, String>{'etag': '"v1"'};
    if (range != null) {
      start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      if (start >= body.length) {
        return http.StreamedResponse(const Stream.empty(), 416,
            headers: {'content-range': 'bytes */${body.length}'});
      }
      status = 206;
      headers['content-range'] =
          'bytes $start-${body.length - 1}/${body.length}';
    }
    final data = body.sublist(start);
    Stream<List<int>> chunks() async* {
      for (var i = 0; i < data.length; i += chunk) {
        yield data.sublist(i, i + chunk > data.length ? data.length : i + chunk);
      }
    }

    return http.StreamedResponse(chunks(), status,
        contentLength: data.length, headers: headers);
  });
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('insato_models'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  ModelManager manager(http.Client client) => ModelManager(tmp.path,
      client: client,
      catalog: const [_single, _whisper],
      sleep: (_) async {},
      retryBaseDelay: Duration.zero);

  test('initial state is notDownloaded and refresh keeps it', () async {
    final m = manager(_server(Uint8List(0)));
    expect(m.stateOf('test-vad').status, ModelStatus.notDownloaded);
    await m.refresh();
    expect(m.stateOf('test-whisper').status, ModelStatus.notDownloaded);
    expect(() => m.stateOf('unknown'), throwsA(isA<ModelException>()));
    await m.dispose();
  });

  test('downloads a single-file model with progress and resolves it',
      () async {
    final body = _bytes(10000);
    final m = manager(_server(body));
    final seen = <ModelState>[];
    final sub = m.statesStream.listen((s) => seen.add(s['test-vad']!));
    await m.download('test-vad');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(m.isReady('test-vad'), isTrue);
    expect(seen.any((s) => s.status == ModelStatus.downloading), isTrue);
    final progresses = seen
        .where((s) => s.status == ModelStatus.downloading)
        .map((s) => s.progress)
        .toList();
    for (var i = 1; i < progresses.length; i++) {
      expect(progresses[i], greaterThanOrEqualTo(progresses[i - 1]));
    }
    final path = await m.filePath('test-vad');
    expect(p.basename(path), 'silero_vad.onnx');
    expect(File(path).readAsBytesSync(), body);
    expect(File(p.join(tmp.path, 'test-vad', kModelMarkerFile)).existsSync(),
        isTrue);
    // No leftovers.
    expect(Directory(p.join(tmp.path, '.downloads')).listSync(), isEmpty);
    await m.dispose();

    // A fresh manager sees the installed model after refresh.
    final m2 = manager(_server(body));
    await m2.refresh();
    expect(m2.isReady('test-vad'), isTrue);
    await m2.dispose();
  });

  test('downloads, extracts (filtered) and verifies a tar.bz2 model',
      () async {
    final m = manager(_server(_whisperArchive()));
    await m.download('test-whisper');
    expect(m.isReady('test-whisper'), isTrue);
    final paths = await m.whisperPaths('test-whisper');
    expect(p.basename(paths.encoder), 'tiny-encoder.int8.onnx');
    expect(p.basename(paths.decoder), 'tiny-decoder.int8.onnx');
    expect(p.basename(paths.tokens), 'tiny-tokens.txt');
    expect(File(paths.encoder).readAsBytesSync(), _bytes(3000, 1));
    // fp32 weights and other files were not extracted.
    final names = listModelFilesSync(m.modelDir('test-whisper'))
        .map(p.basename)
        .toSet();
    expect(names, {
      'tiny-encoder.int8.onnx',
      'tiny-decoder.int8.onnx',
      'tiny-tokens.txt',
    });
    expect(() => m.filePath('test-whisper'), throwsA(isA<ModelException>()));
    await m.dispose();
  });

  test('resumes a partial download with a Range request', () async {
    final body = _bytes(8000);
    final dl = Directory(p.join(tmp.path, '.downloads'))..createSync();
    File(p.join(dl.path, 'test-vad.part')).writeAsBytesSync(body.sublist(0, 3000));
    File(p.join(dl.path, 'test-vad.part.json')).writeAsStringSync(jsonEncode(
        {'url': _single.url, 'validator': '"v1"', 'total': body.length}));
    final log = <http.BaseRequest>[];
    final m = manager(_server(body, log: log));
    await m.refresh();
    expect(m.stateOf('test-vad').status, ModelStatus.notDownloaded);
    expect(m.stateOf('test-vad').progress, closeTo(3000 / 8000, 1e-9));
    await m.download('test-vad');
    expect(log.single.headers['Range'], 'bytes=3000-');
    expect(log.single.headers['If-Range'], '"v1"');
    expect(File(await m.filePath('test-vad')).readAsBytesSync(), body);
    await m.dispose();
  });

  test('restarts from scratch when the server ignores Range (200)',
      () async {
    final body = _bytes(5000);
    final dl = Directory(p.join(tmp.path, '.downloads'))..createSync();
    File(p.join(dl.path, 'test-vad.part')).writeAsBytesSync(_bytes(2000, 99));
    File(p.join(dl.path, 'test-vad.part.json'))
        .writeAsStringSync(jsonEncode({'url': _single.url, 'total': 5000}));
    final m = manager(_server(body, onRequest: (req, n) {
      final data = body;
      return http.StreamedResponse(Stream.value(data), 200,
          contentLength: data.length);
    }));
    await m.download('test-vad');
    expect(File(await m.filePath('test-vad')).readAsBytesSync(), body);
    await m.dispose();
  });

  test('retries transient server errors then succeeds', () async {
    final body = _bytes(4000);
    final log = <http.BaseRequest>[];
    final m = manager(_server(body, log: log, onRequest: (req, n) {
      if (n <= 2) {
        return http.StreamedResponse(const Stream.empty(), 503);
      }
      return null;
    }));
    await m.download('test-vad');
    expect(log, hasLength(3));
    expect(m.isReady('test-vad'), isTrue);
    await m.dispose();
  });

  test('resumes after a connection drop mid-stream', () async {
    final body = _bytes(6000);
    final log = <http.BaseRequest>[];
    final m = manager(_server(body, log: log, onRequest: (req, n) {
      if (n == 1) {
        Stream<List<int>> broken() async* {
          yield body.sublist(0, 2500);
          throw const SocketException('connection reset');
        }

        return http.StreamedResponse(broken(), 200,
            contentLength: body.length, headers: {'etag': '"v1"'});
      }
      return null;
    }));
    await m.download('test-vad');
    expect(log, hasLength(2));
    expect(log[1].headers['Range'], 'bytes=2500-');
    expect(File(await m.filePath('test-vad')).readAsBytesSync(), body);
    await m.dispose();
  });

  test('gives up after maxAttempts and reports failed state', () async {
    final m = manager(_server(Uint8List(0), onRequest: (req, n) {
      throw const SocketException('offline');
    }));
    await expectLater(m.download('test-vad'), throwsA(isA<ModelException>()));
    expect(m.stateOf('test-vad').status, ModelStatus.failed);
    expect(m.stateOf('test-vad').error, isNotEmpty);
    await m.dispose();
  });

  test('HTTP 404 fails immediately without retries', () async {
    var calls = 0;
    final m = manager(_server(Uint8List(0), onRequest: (req, n) {
      calls++;
      return http.StreamedResponse(const Stream.empty(), 404);
    }));
    await expectLater(m.download('test-vad'), throwsA(isA<ModelException>()));
    expect(calls, 1);
    await m.dispose();
  });

  test('cancel keeps the partial file and reports cancellation', () async {
    final body = _bytes(50000);
    final gate = Completer<void>();
    late ModelManager m;
    m = manager(_server(body, onRequest: (req, n) {
      Stream<List<int>> slow() async* {
        yield body.sublist(0, 1000);
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        yield body.sublist(1000, 2000);
        yield body.sublist(2000);
      }

      return http.StreamedResponse(slow(), 200, contentLength: body.length);
    }));
    final f = m.download('test-vad');
    expect(identical(m.download('test-vad'), f), isTrue);
    await gate.future;
    m.cancel('test-vad');
    await expectLater(f, throwsA(isA<ModelDownloadCancelledException>()));
    expect(m.isDownloading('test-vad'), isFalse);
    expect(m.stateOf('test-vad').status, ModelStatus.notDownloaded);
    expect(File(p.join(tmp.path, '.downloads', 'test-vad.part')).existsSync(),
        isTrue);
    await m.dispose();
  });

  test('corrupt archive fails and discards the partial download', () async {
    final m = manager(_server(_bytes(3000)));
    await expectLater(
        m.download('test-whisper'), throwsA(isA<ModelException>()));
    expect(m.stateOf('test-whisper').status, ModelStatus.failed);
    expect(
        File(p.join(tmp.path, '.downloads', 'test-whisper.part')).existsSync(),
        isFalse);
    expect(m.modelDir('test-whisper'), isNot(predicate((String d) => Directory(d).existsSync())));
    await m.dispose();
  });

  test('archive without required files fails verification', () async {
    final m = manager(_server(_tarBz2({'x/readme.txt': utf8.encode('hi')})));
    await expectLater(
        m.download('test-whisper'), throwsA(isA<ModelException>()));
    expect(m.stateOf('test-whisper').status, ModelStatus.failed);
    await m.dispose();
  });

  test('delete removes an installed model', () async {
    final m = manager(_server(_bytes(1000)));
    await m.download('test-vad');
    await m.delete('test-vad');
    expect(m.stateOf('test-vad').status, ModelStatus.notDownloaded);
    expect(Directory(m.modelDir('test-vad')).existsSync(), isFalse);
    await expectLater(
        m.resolvedPaths('test-vad'), throwsA(isA<ModelException>()));
    await m.dispose();
  });

  test('incomplete install directory is reported as failed', () async {
    Directory(p.join(tmp.path, 'test-whisper')).createSync();
    File(p.join(tmp.path, 'test-whisper', 'x-encoder.onnx'))
        .writeAsBytesSync([1]);
    final m = manager(_server(Uint8List(0)));
    await m.refresh();
    expect(m.stateOf('test-whisper').status, ModelStatus.failed);
    await m.dispose();
  });

  group('helpers', () {
    test('parseContentRange', () {
      final r = parseContentRange('bytes 100-199/1000')!;
      expect([r.start, r.end, r.total], [100, 199, 1000]);
      expect(parseContentRange('bytes 0-9/*')!.total, isNull);
      expect(parseContentRange('bytes */500')!.total, 500);
      expect(parseContentRange('bytes 9-0/10'), isNull);
      expect(parseContentRange('items 0-1/2'), isNull);
      expect(parseContentRange(null), isNull);
    });

    test('safeArchiveEntryPath rejects traversal', () {
      expect(safeArchiveEntryPath('a/b/c.onnx'), p.join('a', 'b', 'c.onnx'));
      expect(safeArchiveEntryPath('./a//b.txt'), p.join('a', 'b.txt'));
      expect(safeArchiveEntryPath('../evil'), isNull);
      expect(safeArchiveEntryPath('a/../../evil'), isNull);
      expect(safeArchiveEntryPath('/etc/passwd'), isNull);
      expect(safeArchiveEntryPath(r'C:\x\y'), isNull);
      expect(safeArchiveEntryPath('./'), isNull);
    });

    test('extractTarBz2Sync extracts safely', () {
      final archive = File(p.join(tmp.path, 'a.tar.bz2'))
        ..writeAsBytesSync(_tarBz2({
          'dir/one.onnx': _bytes(100),
          'dir/sub/two.txt': utf8.encode('two'),
          '../escape.txt': utf8.encode('evil'),
        }));
      final out = p.join(tmp.path, 'out');
      final written = extractTarBz2Sync(archive.path, out);
      expect(written.toSet(),
          {p.join('dir', 'one.onnx'), p.join('dir', 'sub', 'two.txt')});
      expect(File(p.join(out, 'dir', 'sub', 'two.txt')).readAsStringSync(),
          'two');
      expect(File(p.join(tmp.path, 'escape.txt')).existsSync(), isFalse);

      final filtered = extractTarBz2Sync(archive.path, p.join(tmp.path, 'o2'),
          includeGlobs: ['*.onnx']);
      expect(filtered, [p.join('dir', 'one.onnx')]);
    });

    test('extractTarBz2Sync throws on corrupt data', () {
      final f = File(p.join(tmp.path, 'bad.tar.bz2'))
        ..writeAsBytesSync(_bytes(500));
      expect(() => extractTarBz2Sync(f.path, p.join(tmp.path, 'o')),
          throwsA(anything));
    });
  });
}
