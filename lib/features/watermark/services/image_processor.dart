import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);

  final String message;

  @override
  String toString() => 'ImageProcessingException: $message';
}

/// A downscaled, correctly oriented preview plus the full-size dimensions.
class PreviewImage {
  const PreviewImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  /// JPEG bytes of the preview.
  final Uint8List bytes;

  /// Oriented size of the full-resolution original.
  final int width;
  final int height;
}

/// A rendered watermark as straight (non-premultiplied) RGBA pixels and
/// where it goes on the oriented original.
class OverlayBitmap {
  const OverlayBitmap({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int left;
  final int top;
  final int width;
  final int height;
  final Uint8List rgba;
}

/// JPEG decoding, orientation and compositing in a background isolate, so
/// large photos never block the UI thread. Only the watermark's own area is
/// passed in as pixels, keeping memory use close to one decoded image.
class ImageProcessor {
  const ImageProcessor({
    this.maxPixels = 50000000,
    this.previewMaxSide = 1600,
    this.jpegQuality = 92,
  });

  /// Larger images are rejected instead of risking an out-of-memory crash.
  final int maxPixels;
  final int previewMaxSide;
  final int jpegQuality;

  Future<PreviewImage> loadPreview(String path) {
    final maxPixels = this.maxPixels;
    final maxSide = previewMaxSide;
    return Isolate.run(() => _preview(path, maxPixels, maxSide));
  }

  /// Draws [overlay] onto the oriented original at [sourcePath] and writes
  /// a new JPEG to [targetPath]. Never writes to [sourcePath].
  Future<void> composeToFile({
    required String sourcePath,
    required String targetPath,
    required OverlayBitmap overlay,
    required int expectedWidth,
    required int expectedHeight,
  }) {
    if (sourcePath == targetPath) {
      throw const ImageProcessingException('Refusing to overwrite original');
    }
    final maxPixels = this.maxPixels;
    final quality = jpegQuality;
    return Isolate.run(
      () => _compose(
        sourcePath,
        targetPath,
        overlay,
        expectedWidth,
        expectedHeight,
        maxPixels,
        quality,
      ),
    );
  }
}

PreviewImage _preview(String path, int maxPixels, int maxSide) {
  final image = _decodeOriented(path, maxPixels);
  final longSide = image.width > image.height ? image.width : image.height;
  final preview = longSide <= maxSide
      ? image
      : img.copyResize(
          image,
          width: image.width >= image.height ? maxSide : null,
          height: image.height > image.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        );
  return PreviewImage(
    bytes: img.encodeJpg(preview, quality: 85),
    width: image.width,
    height: image.height,
  );
}

void _compose(
  String sourcePath,
  String targetPath,
  OverlayBitmap overlay,
  int expectedWidth,
  int expectedHeight,
  int maxPixels,
  int quality,
) {
  final image = _decodeOriented(sourcePath, maxPixels);
  if (image.width != expectedWidth || image.height != expectedHeight) {
    throw ImageProcessingException(
      'Photo changed size (${image.width}×${image.height}, expected '
      '$expectedWidth×$expectedHeight)',
    );
  }
  if (overlay.rgba.lengthInBytes != overlay.width * overlay.height * 4) {
    throw const ImageProcessingException('Watermark pixels are incomplete');
  }

  final layer = img.Image.fromBytes(
    width: overlay.width,
    height: overlay.height,
    bytes: overlay.rgba.buffer,
    bytesOffset: overlay.rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  img.compositeImage(image, layer, dstX: overlay.left, dstY: overlay.top);

  final encoded = img.encodeJpg(image, quality: quality);
  File(targetPath).writeAsBytesSync(encoded, flush: true);
}

/// Decodes a JPEG and applies its EXIF orientation, so pixels are upright
/// and the output needs no orientation tag.
img.Image _decodeOriented(String path, int maxPixels) {
  final Uint8List bytes;
  try {
    bytes = File(path).readAsBytesSync();
  } on FileSystemException catch (e) {
    throw ImageProcessingException('Photo could not be read: ${e.message}');
  }

  final img.Image? decoded;
  try {
    decoded = img.decodeJpg(bytes, maxPixels: maxPixels);
  } catch (e) {
    throw ImageProcessingException('Photo could not be decoded: $e');
  }
  if (decoded == null) {
    throw const ImageProcessingException('The file is not a readable JPEG');
  }

  final orientation = decoded.exif.imageIfd.orientation;
  if (orientation == null || orientation == 1) return decoded;
  return img.bakeOrientation(decoded);
}
