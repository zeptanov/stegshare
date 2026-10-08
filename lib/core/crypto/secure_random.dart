import 'dart:math';
import 'dart:typed_data';

/// Cryptographically secure random bytes (OS CSPRNG via Random.secure()).
class SecureRandomBytes {
  static final Random _rng = Random.secure();

  static Uint8List next(int length) {
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = _rng.nextInt(256);
    }
    return out;
  }
}