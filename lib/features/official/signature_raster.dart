// Rasterises a vector signature (normalised strokes) to a transparent PNG
// for Word documents; PDFs draw the strokes as vectors instead.
//
// Pure Dart (package:image), unit-tested.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'official_models.dart';

/// PNG of [s] [width] pixels wide (height from its aspect ratio), dark
/// blue ink on a transparent background.
Uint8List signaturePng(MinutesSignature s, {int width = 600}) {
  final aspect = s.aspectRatio <= 0 ? 3.0 : s.aspectRatio;
  final height = math.max(1, (width / aspect).round());
  final image = img.Image(width: width, height: height, numChannels: 4)
    ..clear(img.ColorRgba8(255, 255, 255, 0));
  final ink = img.ColorRgba8(0x1F, 0x2A, 0x44, 255);
  final thickness = math.max(2, width ~/ 150);
  int px(double v) => (v * (width - 1)).round();
  int py(double v) => (v * (height - 1)).round();
  for (final stroke in s.strokes) {
    if (stroke.length == 1) {
      img.fillCircle(
        image,
        x: px(stroke.first.x),
        y: py(stroke.first.y),
        radius: thickness ~/ 2 + 1,
        color: ink,
        antialias: true,
      );
      continue;
    }
    for (var i = 1; i < stroke.length; i++) {
      img.drawLine(
        image,
        x1: px(stroke[i - 1].x),
        y1: py(stroke[i - 1].y),
        x2: px(stroke[i].x),
        y2: py(stroke[i].y),
        color: ink,
        antialias: true,
        thickness: thickness,
      );
    }
  }
  return img.encodePng(image);
}

/// Pixel size of a PNG / JPEG / GIF / BMP image, or null when it cannot be
/// decoded.
({int width, int height})? imageSize(Uint8List bytes) {
  try {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (width: info.width, height: info.height);
  } on Object {
    return null;
  }
}
