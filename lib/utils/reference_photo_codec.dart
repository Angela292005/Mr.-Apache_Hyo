import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const maxReferencePhotoBytes = 384 * 1024;

Uint8List compressReferencePhoto(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) {
    throw const FormatException('El archivo no contiene una imagen válida.');
  }

  var image = decoded;
  const maxDimension = 1280;
  if (math.max(image.width, image.height) > maxDimension) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: maxDimension,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: maxDimension,
            interpolation: img.Interpolation.average,
          );
  }

  const qualities = [75, 65, 55, 45, 35];
  for (var attempt = 0; attempt < 12; attempt++) {
    for (final quality in qualities) {
      final encoded = img.encodeJpg(
        image,
        quality: quality,
        chroma: img.JpegChroma.yuv420,
      );
      if (encoded.length <= maxReferencePhotoBytes) {
        return encoded;
      }
    }

    final longestSide = math.max(image.width, image.height);
    if (longestSide <= 320) break;
    final targetSize = (longestSide * 0.8).round();
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: targetSize,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: targetSize,
            interpolation: img.Interpolation.average,
          );
  }

  throw StateError(
    'No se pudo reducir la foto al tamaño permitido para guardarla en Firestore.',
  );
}
