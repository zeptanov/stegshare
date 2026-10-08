import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../errors.dart';

class Compressor {
  static const maxDecompressedBytes = 1 << 30;

  static Uint8List compress(Uint8List data, {int level = 6}) =>
      Uint8List.fromList(const ZLibEncoder().encode(data, level: level));

  /// Returns null when compression doesn't help.
  static Uint8List? compressIfSmaller(Uint8List data) {
    final c = compress(data);
    return c.length < data.length ? c : null;
  }

  static Uint8List decompress(Uint8List data, {int maxBytes = maxDecompressedBytes}) {
    try {
      final out = ZLibDecoder().decodeBytes(data, verify: true);
      if (out.length > maxBytes) {
        throw const ContainerFormatException('Decompressed payload exceeds limit.');
      }
      return Uint8List.fromList(out);
    } on StegShareException {
      rethrow;
    } catch (_) {
      throw const ContainerFormatException('Corrupted compressed payload.');
    }
  }
}