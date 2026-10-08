import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

class Hashing {
  static Uint8List sha256(List<int> data) =>
      Uint8List.fromList(crypto.sha256.convert(data).bytes);

  /// Streaming SHA-256 for large inputs (files are hashed in chunks).
  static Future<Uint8List> sha256Stream(Stream<List<int>> stream) async {
    final digest = await crypto.sha256.bind(stream).first;
    return Uint8List.fromList(digest.bytes);
  }

  static String hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List fromHex(String hex) {
    if (hex.length.isOdd) throw const FormatException('Odd hex length');
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}