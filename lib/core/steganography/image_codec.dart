import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../errors.dart';
import 'stego_image.dart';

/// Decodes any supported raster (PNG/JPEG/BMP/...) into RGBA8; always encodes
/// PNG (lossless) — JPEG would destroy LSB data.
class StegoImageCodec {
  static const maxPixels = 64 * 1024 * 1024; // 64 MP guard against memory blow-up

  static StegoImage decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const StegShareException('Unsupported or corrupted image.');
    if (decoded.width * decoded.height > maxPixels) {
      throw const StegShareException('Image is too large (max 64 megapixels).');
    }
    final converted = decoded.convert(format: img.Format.uint8, numChannels: 4);
    return StegoImage(
      width: converted.width,
      height: converted.height,
      rgba: Uint8List.fromList(converted.getBytes(order: img.ChannelOrder.rgba)),
    );
  }

  static Uint8List encodePng(StegoImage image) {
    final im = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: image.rgba.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
    return img.encodePng(im, level: 6);
  }
}