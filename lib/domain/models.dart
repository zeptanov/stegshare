import 'dart:typed_data';

import '../core/container/container_codec.dart';
import '../core/container/container_format.dart';
import '../core/container/manifest.dart';
import '../core/crypto/symmetric_cipher.dart';

/// Item to embed; either inline bytes or a file path read inside the worker.
class HidePayloadItem {
  final PayloadType type;
  final String name;
  final String mime;
  final Uint8List? bytes;
  final String? path;

  const HidePayloadItem.text({required this.name, required Uint8List data})
      : type = PayloadType.text,
        mime = 'text/plain; charset=utf-8',
        bytes = data,
        path = null;

  const HidePayloadItem.file({required this.name, required this.mime, required String filePath})
      : type = PayloadType.file,
        bytes = null,
        path = filePath;
}

class HideJob {
  final Uint8List imageBytes;
  final List<HidePayloadItem> items;
  final EncryptionSpec spec;
  final bool compress;
  final String? scatterKey;
  const HideJob({
    required this.imageBytes,
    required this.items,
    required this.spec,
    this.compress = true,
    this.scatterKey,
  });
}

class ExtractJob {
  final Uint8List imageBytes;
  final String? password;
  final Uint8List? recipientSeed;
  final String? scatterKey;
  const ExtractJob({required this.imageBytes, this.password, this.recipientSeed, this.scatterKey});
}

class ExtractResult {
  final List<ExtractedItem> items;
  final KeyMode keyMode;
  final EncryptionAlgorithm algorithm;
  final bool compressed;
  final SignatureStatus signature;
  final Uint8List? signerPublicKey;
  const ExtractResult({
    required this.items,
    required this.keyMode,
    required this.algorithm,
    required this.compressed,
    required this.signature,
    this.signerPublicKey,
  });
}

class ImageInspection {
  final int width;
  final int height;
  final int capacitySequential;
  final int capacityKeyed;
  const ImageInspection({
    required this.width,
    required this.height,
    required this.capacitySequential,
    required this.capacityKeyed,
  });
}