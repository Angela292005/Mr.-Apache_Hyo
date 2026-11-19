import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../lib/utils/reference_photo_codec.dart';

void main() {
  test('compresses a photo within Firestore document budget', () {
    final image = img.Image(width: 1200, height: 900);
    var seed = 7;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        seed = (seed * 1664525 + 1013904223) & 0x7fffffff;
        image.setPixelRgb(
          x,
          y,
          (seed >> 16) & 0xff,
          (seed >> 8) & 0xff,
          seed & 0xff,
        );
      }
    }

    final compressed = compressReferencePhoto(img.encodePng(image));

    expect(compressed.length, lessThanOrEqualTo(maxReferencePhotoBytes));
    expect(base64Encode(compressed).length, lessThanOrEqualTo(512 * 1024));
    expect(img.decodeImage(compressed), isNotNull);
  });

  test('rejects bytes that are not a supported image', () {
    expect(
      () => compressReferencePhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
