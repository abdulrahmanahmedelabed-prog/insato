import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:insato/features/import_audio/audio_formats.dart';
import 'package:insato/features/import_audio/import_ui.dart'
    show kAudioTypeGroup;

Uint8List _head(List<int> bytes) {
  final out = Uint8List(64);
  out.setRange(0, bytes.length, bytes);
  return out;
}

Uint8List _ascii(String s, {int at = 0, List<int> prefix = const []}) {
  final out = Uint8List(64);
  out.setRange(0, prefix.length, prefix);
  out.setRange(at, at + s.length, s.codeUnits);
  return out;
}

AudioContainer? _sniff(Uint8List head) => switch (sniffAudioHeader(head)) {
  SniffedAudio(:final container) => container,
  _ => null,
};

void main() {
  group('sniffAudioHeader', () {
    test('recognises the magic bytes of every supported container', () {
      final wav = _ascii('RIFF')..setRange(8, 12, 'WAVE'.codeUnits);
      expect(_sniff(wav), AudioContainer.wav);
      final aiff = _ascii('FORM')..setRange(8, 12, 'AIFF'.codeUnits);
      expect(_sniff(aiff), AudioContainer.aiff);
      expect(_sniff(_ascii('caff')), AudioContainer.caf);
      expect(_sniff(_ascii('#!AMR\n')), AudioContainer.amrNb);
      expect(_sniff(_ascii('#!AMR-WB\n')), AudioContainer.amrWb);
      expect(_sniff(_ascii('fLaC')), AudioContainer.flac);
      final ogg = _ascii('OggS');
      expect(_sniff(ogg), AudioContainer.ogg);
      ogg.setRange(28, 36, 'OpusHead'.codeUnits);
      expect(_sniff(ogg), AudioContainer.opus);
      final m4a = _ascii('ftypM4A ', at: 4);
      expect(_sniff(m4a), AudioContainer.mp4);
      final threeGp = _ascii('ftyp3gp4', at: 4);
      expect(_sniff(threeGp), AudioContainer.threeGp);
      expect(_sniff(_ascii('ID3')), AudioContainer.mp3);
      // MPEG-1 layer III frame sync without ID3 tag.
      expect(_sniff(_head([0xFF, 0xFB, 0x90, 0x64])), AudioContainer.mp3);
      // ADTS AAC (layer bits 00).
      expect(_sniff(_head([0xFF, 0xF1, 0x50, 0x80])), AudioContainer.aac);
      expect(
        _sniff(_head([0x1A, 0x45, 0xDF, 0xA3])),
        AudioContainer.webm,
      );
      expect(_sniff(_head([0x30, 0x26, 0xB2, 0x75])), AudioContainer.wma);
    });

    test('documents and images are not audio', () {
      expect(sniffAudioHeader(_ascii('%PDF-1.7')), isA<SniffedNotAudio>());
      expect(sniffAudioHeader(_ascii('PK')), isA<SniffedNotAudio>());
      expect(
        sniffAudioHeader(_head([0x89, 0x50, 0x4E, 0x47])),
        isA<SniffedNotAudio>(),
      );
      expect(
        sniffAudioHeader(_head([0xFF, 0xD8, 0xFF, 0xE0])),
        isA<SniffedNotAudio>(),
      );
      expect(sniffAudioHeader(Uint8List(2)), isA<SniffedUnknown>());
      expect(sniffAudioHeader(_head([1, 2, 3, 4])), isA<SniffedUnknown>());
    });
  });

  group('detectAudioContainer', () {
    test('magic bytes win over a wrong extension', () {
      expect(
        detectAudioContainer(_ascii('#!AMR\n'), 'call.m4a'),
        AudioContainer.amrNb,
      );
    });

    test('the extension decides for unknown headers', () {
      final unknown = _head([1, 2, 3, 4]);
      expect(detectAudioContainer(unknown, 'x.OPUS'), AudioContainer.opus);
      expect(detectAudioContainer(unknown, 'x.3gpp'), AudioContainer.threeGp);
      expect(detectAudioContainer(unknown, 'notes.txt'), isNull);
      expect(detectAudioContainer(unknown, 'noext'), isNull);
    });

    test('a PDF named .mp3 is refused', () {
      expect(detectAudioContainer(_ascii('%PDF'), 'song.mp3'), isNull);
    });
  });

  test('fileExtension', () {
    expect(fileExtension('a/b/Call recording.M4A'), 'm4a');
    expect(fileExtension(r'C:\x\voice.amr'), 'amr');
    expect(fileExtension('.hidden'), '');
    expect(fileExtension('trailing.'), '');
  });

  test('the chooser offers exactly the supported extensions', () {
    expect(kAudioTypeGroup.extensions!.toSet(), kImportExtensions.toSet());
    expect(kAudioTypeGroup.uniformTypeIdentifiers, contains('public.audio'));
    expect(kAudioTypeGroup.mimeTypes, contains('audio/*'));
  });

  test('every requested format is accepted', () {
    for (final ext in const [
      'm4a', 'aac', 'mp3', 'wav', 'amr', 'awb', 'ogg', 'opus', 'flac', //
      '3gp', 'mp4', 'caf',
    ]) {
      expect(containerForExtension(ext), isNotNull, reason: ext);
    }
  });
}
