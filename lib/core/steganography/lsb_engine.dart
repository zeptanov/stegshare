import 'dart:typed_data';

import '../errors.dart';
import '../util/cancellation.dart';
import 'bit_position_source.dart';
import 'steganography_engine.dart';
import 'stego_image.dart';

/// 1 bit per R/G/B channel, 32-bit big-endian length prefix, then data.
class LsbRgbEngine implements SteganographyEngine {
  static const headerBits = 32;
  static const keyedLoadPercent = 90;

  @override
  String get id => 'lsb-rgb-v1';

  int _slots(StegoImage img) => img.pixelCount * 3;

  @override
  int capacityBytes(StegoImage image, {bool keyed = false}) {
    var slots = _slots(image);
    if (keyed) slots = slots * keyedLoadPercent ~/ 100;
    final bits = slots - headerBits;
    return bits <= 0 ? 0 : bits ~/ 8;
  }

  static int _byteIndex(int slot) => (slot ~/ 3) * 4 + (slot % 3);

  @override
  void embed(StegoImage image, Uint8List data,
      {Uint8List? key, ProgressFn? onProgress, CancellationToken? token}) {
    final cap = capacityBytes(image, keyed: key != null);
    if (data.length > cap) {
      throw CapacityException('Payload is ${data.length} bytes, image holds at most $cap bytes.');
    }
    final src = BitPositionSource.create(slots: _slots(image), key: key);
    final rgba = image.rgba;
    void put(int bit) {
      final i = _byteIndex(src.next());
      rgba[i] = (rgba[i] & 0xFE) | bit;
    }

    final len = data.length;
    for (var i = headerBits - 1; i >= 0; i--) {
      put((len >> i) & 1);
    }
    for (var b = 0; b < len; b++) {
      final v = data[b];
      for (var i = 7; i >= 0; i--) {
        put((v >> i) & 1);
      }
      if ((b & 0xFFFF) == 0) {
        token?.throwIfCancelled();
        onProgress?.call(b / len, 'Embedding');
      }
    }
    onProgress?.call(1, 'Embedding');
  }

  @override
  Uint8List? extract(StegoImage image,
      {Uint8List? key, ProgressFn? onProgress, CancellationToken? token}) {
    final cap = capacityBytes(image, keyed: key != null);
    if (cap <= 0) return null;
    final src = BitPositionSource.create(slots: _slots(image), key: key);
    final rgba = image.rgba;
    int get() => rgba[_byteIndex(src.next())] & 1;

    var len = 0;
    for (var i = 0; i < headerBits; i++) {
      len = (len << 1) | get();
    }
    if (len <= 0 || len > cap) return null;
    final out = Uint8List(len);
    for (var b = 0; b < len; b++) {
      var v = 0;
      for (var i = 0; i < 8; i++) {
        v = (v << 1) | get();
      }
      out[b] = v;
      if ((b & 0xFFFF) == 0) {
        token?.throwIfCancelled();
        onProgress?.call(b / len, 'Reading bits');
      }
    }
    return out;
  }
}