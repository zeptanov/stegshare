import 'dart:typed_data';

/// Decoded raster: 8-bit RGBA, row-major. Only R,G,B carry hidden bits; alpha is
/// preserved untouched (modifying alpha is both visible and lossy-prone).
class StegoImage {
  final int width;
  final int height;
  final Uint8List rgba;

  StegoImage({required this.width, required this.height, required this.rgba}) {
    if (rgba.length != width * height * 4) {
      throw ArgumentError('rgba buffer size does not match dimensions');
    }
  }

  int get pixelCount => width * height;
}