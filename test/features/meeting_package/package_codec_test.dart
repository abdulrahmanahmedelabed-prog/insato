import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:insato/core/models.dart';
import 'package:insato/features/meeting_package/package_codec.dart';
import 'package:insato/features/meeting_package/package_crypto.dart';
import 'package:insato/features/meeting_package/package_format.dart';

Float32List _vec(int seed) {
  final r = math.Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < 8; i++) r.nextDouble() - 0.5,
  ]);
}

MeetingPackage samplePackage({bool voiceprints = true, bool audio = true}) =>
    MeetingPackage(
      manifest: PackageManifest(
        appVersion: '1.2.0-test',
        schemaVersion: 6,
        exportedAt: DateTime.utc(2026, 11, 20, 9),
        exportedMonotonicUs: 123456,
        device: const PackageDevice(name: 'هاتف القاعة ب', platform: 'android'),
        meetingId: 'm-remote',
        title: 'اجتماع الفريق الميداني',
        startedAt: DateTime.utc(2026, 11, 20, 8, 0, 5),
        durationMs: 60000,
        includes: PackageIncludes(
          audio: audio,
          voiceprints: voiceprints,
          minutes: true,
        ),
        context: const MeetingContext(agenda: ['الميزانية', 'الجدول']),
      ),
      segments: [
        PackageSegment(
          index: 0,
          startMs: 1000,
          endMs: 4000,
          text: 'نبدأ بمراجعة الميزانية',
          speakerKey: 'sp-a',
          language: 'ar',
          asrConfidence: 0.9,
          snrDb: 21.5,
          embedding: _vec(1),
        ),
        const PackageSegment(
          index: 1,
          startMs: 5000,
          endMs: 7000,
          text: '',
          kind: SegmentKind.unintelligible,
        ),
      ],
      speakers: [
        PackageSpeaker(
          key: 'sp-a',
          name: 'متحدث 1',
          colorValue: 0xFF1565C0,
          isNamedByUser: false,
          centroid: _vec(2),
          embeddingCount: 7,
        ),
      ],
      minutes: Minutes(
        title: 'محضر',
        summary: 'ملخص',
        attendees: const ['متحدث 1'],
        topics: const [],
        decisions: const [],
        actionItems: const [],
        openQuestions: const [],
        languagesDetected: const ['ar'],
        generatedAt: DateTime.utc(2026, 11, 20, 10),
        model: 'test',
      ),
      audioWav: audio
          ? Uint8List.fromList(List.generate(5000, (i) => (i * 7) % 256))
          : null,
    );

Uint8List _rezip(Uint8List bytes, Uint8List Function(String, Uint8List) edit) {
  final a = ZipDecoder().decodeBytes(bytes);
  final out = Archive();
  for (final f in a) {
    out.add(ArchiveFile.bytes(f.name, edit(f.name, f.readBytes()!)));
  }
  return Uint8List.fromList(ZipEncoder().encodeBytes(out));
}

void main() {
  group('round trip', () {
    test('plain package keeps every field', () async {
      final bytes = await encodeMeetingPackage(samplePackage());
      final header = peekMeetingPackage(bytes);
      expect(header.encrypted, isFalse);
      expect(header.manifest!.title, 'اجتماع الفريق الميداني');

      final pkg = await decodeMeetingPackage(bytes);
      final mf = pkg.manifest;
      expect(mf.device.name, 'هاتف القاعة ب');
      expect(mf.startedAt.toUtc(), DateTime.utc(2026, 11, 20, 8, 0, 5));
      expect(mf.exportedMonotonicUs, 123456);
      expect(mf.context.agenda, ['الميزانية', 'الجدول']);
      expect(mf.includes.audio, isTrue);
      expect(mf.includes.voiceprints, isTrue);
      expect(
        mf.entries.keys,
        containsAll([
          PackageEntries.transcript,
          PackageEntries.speakers,
          PackageEntries.minutes,
          PackageEntries.audio,
        ]),
      );
      expect(pkg.segments, hasLength(2));
      expect(pkg.segments[0].text, 'نبدأ بمراجعة الميزانية');
      expect(pkg.segments[0].snrDb, 21.5);
      expect(pkg.segments[0].embedding, _vec(1));
      expect(pkg.segments[1].kind, SegmentKind.unintelligible);
      expect(pkg.speakers.single.centroid, _vec(2));
      expect(pkg.speakers.single.embeddingCount, 7);
      expect(pkg.minutes!.summary, 'ملخص');
      expect(pkg.audioWav, samplePackage().audioWav);
      expect(pkg.encrypted, isFalse);
    });

    test('without voiceprints no centroid or embedding is written', () async {
      final bytes = await encodeMeetingPackage(
        samplePackage(voiceprints: false),
      );
      final raw = ZipDecoder().decodeBytes(bytes);
      for (final f in raw) {
        final text = utf8.decode(f.readBytes()!, allowMalformed: true);
        expect(text.contains('"centroid"'), isFalse, reason: f.name);
        expect(text.contains('"embedding"'), isFalse, reason: f.name);
      }
      final pkg = await decodeMeetingPackage(bytes);
      expect(pkg.manifest.includes.voiceprints, isFalse);
      expect(pkg.speakers.single.centroid, isNull);
      expect(pkg.segments.first.embedding, isNull);
    });

    test('without audio there is no audio entry', () async {
      final pkg = await decodeMeetingPackage(
        await encodeMeetingPackage(samplePackage(audio: false)),
      );
      expect(pkg.audioWav, isNull);
      expect(pkg.manifest.includes.audio, isFalse);
      expect(pkg.manifest.entries.containsKey(PackageEntries.audio), isFalse);
    });
  });

  group('integrity', () {
    test('a modified entry is detected', () async {
      final bytes = await encodeMeetingPackage(samplePackage());
      final tampered = _rezip(bytes, (name, data) {
        if (name != PackageEntries.transcript) return data;
        return Uint8List.fromList(
          utf8.encode(utf8.decode(data).replaceAll('الميزانية', 'الميزانيه')),
        );
      });
      await expectLater(
        decodeMeetingPackage(tampered),
        throwsA(
          isA<PackageException>()
              .having((e) => e.kind, 'kind', PackageErrorKind.tampered)
              .having((e) => e.detail, 'detail', PackageEntries.transcript),
        ),
      );
    });

    test('modified audio is detected', () async {
      final bytes = await encodeMeetingPackage(samplePackage());
      final tampered = _rezip(bytes, (name, data) {
        if (name != PackageEntries.audio) return data;
        return Uint8List.fromList(data)..[100] ^= 1;
      });
      await expectLater(
        decodeMeetingPackage(tampered),
        throwsA(
          isA<PackageException>().having(
            (e) => e.kind,
            'kind',
            PackageErrorKind.tampered,
          ),
        ),
      );
    });

    test('a missing entry is reported as corrupt', () async {
      final bytes = await encodeMeetingPackage(samplePackage());
      final a = ZipDecoder().decodeBytes(bytes);
      final out = Archive();
      for (final f in a) {
        if (f.name != PackageEntries.speakers) out.add(f);
      }
      await expectLater(
        decodeMeetingPackage(Uint8List.fromList(ZipEncoder().encodeBytes(out))),
        throwsA(
          isA<PackageException>().having(
            (e) => e.kind,
            'kind',
            PackageErrorKind.corrupt,
          ),
        ),
      );
    });

    test('random bytes and foreign zips are not packages', () async {
      expect(
        () => peekMeetingPackage(Uint8List.fromList(List.filled(64, 7))),
        throwsA(isA<PackageException>()),
      );
      final other = Archive()..add(ArchiveFile.string('a.txt', 'hello'));
      await expectLater(
        decodeMeetingPackage(
          Uint8List.fromList(ZipEncoder().encodeBytes(other)),
        ),
        throwsA(
          isA<PackageException>().having(
            (e) => e.kind,
            'kind',
            PackageErrorKind.notAPackage,
          ),
        ),
      );
    });

    test('a newer format version is refused', () {
      final j = samplePackage().manifest.toJson()..['format_version'] = 99;
      expect(
        () => PackageManifest.fromJson(j),
        throwsA(
          isA<PackageException>().having(
            (e) => e.kind,
            'kind',
            PackageErrorKind.unsupportedVersion,
          ),
        ),
      );
    });
  });

  group('encryption', () {
    test('round trip with the right password', () async {
      final bytes = await encodeMeetingPackage(
        samplePackage(),
        password: 'كلمة-سر-123',
        kdfIterations: 1000,
      );
      final header = peekMeetingPackage(bytes);
      expect(header.encrypted, isTrue);
      expect(header.manifest, isNull);
      // Nothing readable leaks: no title, no transcript text.
      final raw = ZipDecoder().decodeBytes(bytes);
      expect(raw.find(PackageEntries.manifest), isNull);
      for (final f in raw) {
        final text = utf8.decode(f.readBytes()!, allowMalformed: true);
        expect(text.contains('الميزانية'), isFalse);
        expect(text.contains('كلمة-سر'), isFalse);
      }
      final pkg = await decodeMeetingPackage(bytes, password: 'كلمة-سر-123');
      expect(pkg.encrypted, isTrue);
      expect(pkg.segments.first.text, 'نبدأ بمراجعة الميزانية');
      expect(pkg.audioWav, samplePackage().audioWav);
    });

    test('missing or wrong password', () async {
      final bytes = await encodeMeetingPackage(
        samplePackage(),
        password: 'secret-1',
        kdfIterations: 1000,
      );
      await expectLater(
        decodeMeetingPackage(bytes),
        throwsA(
          isA<PackageException>().having(
            (e) => e.kind,
            'kind',
            PackageErrorKind.passwordRequired,
          ),
        ),
      );
      await expectLater(
        decodeMeetingPackage(bytes, password: 'secret-2'),
        throwsA(
          isA<PackageException>().having(
            (e) => e.kind,
            'kind',
            PackageErrorKind.wrongPassword,
          ),
        ),
      );
    });

    test('a flipped ciphertext bit fails authentication', () async {
      final bytes = await encodeMeetingPackage(
        samplePackage(),
        password: 'secret-1',
        kdfIterations: 1000,
      );
      final tampered = _rezip(bytes, (name, data) {
        if (name != '${PackageEntries.audio}.enc') return data;
        return Uint8List.fromList(data)..[40] ^= 0x10;
      });
      await expectLater(
        decodeMeetingPackage(tampered, password: 'secret-1'),
        throwsA(
          isA<PackageException>().having(
            (e) => e.kind,
            'kind',
            PackageErrorKind.wrongPassword,
          ),
        ),
      );
    });

    test('chunked entries: swapped, truncated and empty', () async {
      final key = await derivePackageKey(
        'pw',
        PackageEnvelope(salt: Uint8List(16), iterations: 10),
      );
      final plain = Uint8List.fromList(List.generate(5000, (i) => i % 251));
      final sealed = encryptEntry('a', plain, key, chunkSize: 1024);
      expect(decryptEntry('a', sealed, key, chunkSize: 1024), plain);
      // Bound to the entry name.
      expect(
        () => decryptEntry('b', sealed, key, chunkSize: 1024),
        throwsA(isA<PackageException>()),
      );
      // Truncated at a chunk boundary: the "last" flag no longer matches.
      final cut = Uint8List.sublistView(sealed, 0, 8 + 2 * (1024 + 16));
      expect(
        () => decryptEntry('a', cut, key, chunkSize: 1024),
        throwsA(isA<PackageException>()),
      );
      final empty = encryptEntry('e', Uint8List(0), key, chunkSize: 1024);
      expect(decryptEntry('e', empty, key, chunkSize: 1024), isEmpty);
    });
  });
}
