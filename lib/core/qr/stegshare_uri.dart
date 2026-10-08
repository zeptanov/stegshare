import 'dart:convert';
import 'dart:typed_data';

import '../crypto/identity.dart';

/// `STEGSHARE://key/v1?enc=<b64url>&sig=<b64url>&name=<text>`
/// `STEGSHARE://msg/v1?d=<b64url container bytes>`  (small payloads only)
sealed class StegShareUriPayload {}

class PublicKeyPayload extends StegShareUriPayload {
  final PublicIdentity identity;
  PublicKeyPayload(this.identity);
}

class MessagePayload extends StegShareUriPayload {
  final Uint8List containerBytes;
  MessagePayload(this.containerBytes);
}

class StegShareUri {
  static const scheme = 'stegshare';
  static const maxLength = 4096;
  static const maxMessageBytes = 2048;

  static String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

  static Uint8List _unb64(String s) {
    final padded = s + '=' * ((4 - s.length % 4) % 4);
    return base64Url.decode(padded);
  }

  static String encodePublicIdentity(PublicIdentity p) =>
      'STEGSHARE://key/v1?enc=${_b64(p.encryptionKey)}&sig=${_b64(p.signingKey)}'
      '&name=${Uri.encodeQueryComponent(p.name)}';

  static String encodeMessage(Uint8List containerBytes) {
    if (containerBytes.length > maxMessageBytes) {
      throw const FormatException('Message too large for QR');
    }
    return 'STEGSHARE://msg/v1?d=${_b64(containerBytes)}';
  }

  static StegShareUriPayload parse(String text) {
    final t = text.trim();
    if (t.length > maxLength) throw const FormatException('QR payload too long');
    if (!t.toLowerCase().startsWith('$scheme://')) {
      throw const FormatException('Not a STEGSHARE URI');
    }
    final uri = Uri.parse('$scheme://${t.substring(scheme.length + 3)}');
    final kind = uri.host;
    final version = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (version != 'v1') throw FormatException('Unsupported URI version "$version"');
    final q = uri.queryParameters;
    switch (kind) {
      case 'key':
        final enc = _unb64(q['enc'] ?? '');
        final sig = _unb64(q['sig'] ?? '');
        if (enc.length != 32 || sig.length != 32) throw const FormatException('Bad key length');
        final name = (q['name'] ?? '').trim();
        if (name.length > 64) throw const FormatException('Name too long');
        return PublicKeyPayload(PublicIdentity(
            name: name.isEmpty ? 'Unnamed' : name, encryptionKey: enc, signingKey: sig));
      case 'msg':
        final d = _unb64(q['d'] ?? '');
        if (d.isEmpty || d.length > maxMessageBytes) throw const FormatException('Bad message size');
        return MessagePayload(d);
      default:
        throw FormatException('Unknown STEGSHARE URI kind "$kind"');
    }
  }
}