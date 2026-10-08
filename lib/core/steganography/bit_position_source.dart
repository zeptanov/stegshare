import 'dart:typed_data';

import '../crypto/hashing.dart';

/// Yields channel-slot indices in [0, slots). Sequential or keyed-pseudo-random.
abstract class BitPositionSource {
  int next();

  static BitPositionSource create({required int slots, Uint8List? key}) =>
      key == null ? SequentialPositionSource(slots) : KeyedPositionSource(slots, key);
}

class SequentialPositionSource implements BitPositionSource {
  final int slots;
  int _i = 0;
  SequentialPositionSource(this.slots);

  @override
  int next() {
    if (_i >= slots) throw StateError('Out of positions');
    return _i++;
  }
}

/// Deterministic, platform-independent xorshift64* seeded from SHA-256(key).
/// NOTE: this is NOT a cryptographic PRNG; it only scatters bit positions so an
/// attacker without the key can't read the stream sequentially. It does not
/// make LSB embedding undetectable by statistical steganalysis.
class KeyedPositionSource implements BitPositionSource {
  final int slots;
  final Uint8List _used;
  int _state;
  int _taken = 0;

  KeyedPositionSource(this.slots, Uint8List key)
      : _used = Uint8List((slots + 7) >> 3),
        _state = _seedFrom(key);

  static int _seedFrom(Uint8List key) {
    final h = Hashing.sha256([...key, ...'STEGSHARE/positions/v1'.codeUnits]);
    var s = 0;
    for (var i = 0; i < 8; i++) {
      s = (s << 8) | h[i];
    }
    return s == 0 ? 0x9E3779B97F4A7C15 : s;
  }

  int _nextRaw() {
    var x = _state;
    x ^= x >>> 12;
    x ^= x << 25;
    x ^= x >>> 27;
    _state = x;
    return (x * 0x2545F4914F6CDD1D) >>> 1; // keep non-negative
  }

  @override
  int next() {
    // Rejection sampling; capacity is capped at 90% load so this stays fast.
    if (_taken >= slots) throw StateError('Out of positions');
    while (true) {
      final idx = _nextRaw() % slots;
      final byte = idx >> 3;
      final mask = 1 << (idx & 7);
      if (_used[byte] & mask == 0) {
        _used[byte] |= mask;
        _taken++;
        return idx;
      }
    }
  }
}