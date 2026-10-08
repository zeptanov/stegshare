import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/container/container_codec.dart';
import '../core/container/container_format.dart';
import '../core/crypto/hashing.dart';
import '../core/errors.dart';
import '../core/steganography/image_codec.dart';
import '../core/steganography/lsb_engine.dart';
import '../core/steganography/steganography_engine.dart';
import '../core/util/cancellation.dart';
import 'models.dart';

/// Pure orchestration (no Flutter, no UI). Runs in an isolate via
/// [StegShareService] and directly in unit tests.
class StegPipeline {
  static SteganographyEngine engine = LsbRgbEngine();

  static Uint8List? scatterKeyBytes(String? key) =>
      (key == null || key.isEmpty) ? null : Uint8List.fromList(utf8.encode(key));

  static Future<ImageInspection> inspect(Uint8List imageBytes, ProgressFn p, CancellationToken t) async {
    final img = StegoImageCodec.decode(imageBytes);
    return ImageInspection(
      width: img.width,
      height: img.height,
      capacitySequential: engine.capacityBytes(img),
      capacityKeyed: engine.capacityBytes(img, keyed: true),
    );
  }

  static Future<Uint8List> hide(HideJob job, ProgressFn progress, CancellationToken token) async {
    progress(0.0, 'Decoding image');
    final image = StegoImageCodec.decode(job.imageBytes);
    final key = scatterKeyBytes(job.scatterKey);
    final capacity = engine.capacityBytes(image, keyed: key != null);
    token.throwIfCancelled();

    // Load payloads, rejecting oversized files before reading them.
    final inputs = <PayloadInput>[];
    for (final it in job.items) {
      Uint8List data;
      if (it.bytes != null) {
        data = it.bytes!;
      } else {
        final f = File(it.path!);
        final len = await f.length();
        if (len > capacity) {
          throw CapacityException('"${it.name}" ($len bytes) exceeds image capacity ($capacity bytes).');
        }
        data = await f.readAsBytes();
      }
      inputs.add(PayloadInput(type: it.type, name: it.name, mime: it.mime, data: data));
      token.throwIfCancelled();
    }

    progress(0.1, 'Building container');
    final container = await ContainerCodec().build(
      items: inputs,
      spec: job.spec,
      compress: job.compress,
      token: token,
      onProgress: (f, s) => progress(0.1 + f * 0.5, s),
    );
    if (container.length > capacity) {
      throw CapacityException(
          'Container is ${container.length} bytes but the image holds only $capacity bytes.');
    }
    engine.embed(image, container,
        key: key, token: token, onProgress: (f, s) => progress(0.6 + f * 0.3, s));
    progress(0.9, 'Encoding PNG');
    final png = StegoImageCodec.encodePng(image);
    progress(1.0, 'Done');
    return png;
  }

  static Future<ExtractResult> extract(ExtractJob job, ProgressFn progress, CancellationToken token) async {
    progress(0.0, 'Decoding image');
    final image = StegoImageCodec.decode(job.imageBytes);
    final key = scatterKeyBytes(job.scatterKey);
    final raw = engine.extract(image, key: key, token: token, onProgress: (f, s) => progress(f * 0.4, s));
    if (raw == null || ContainerCodec.probe(raw) == null) throw const NoContainerFoundException();
    final decoded = await ContainerCodec().open(
      raw,
      password: job.password,
      recipientSeed: job.recipientSeed,
      token: token,
      onProgress: (f, s) => progress(0.4 + f * 0.6, s),
    );
    return ExtractResult(
      items: decoded.items,
      keyMode: decoded.header.keyMode,
      algorithm: decoded.header.encryption,
      compressed: decoded.header.isCompressed,
      signature: decoded.signature,
      signerPublicKey: decoded.signerPublicKey,
    );
  }

  /// Signer fingerprint for display (hash of public key).
  static String fingerprintOf(Uint8List publicKey) =>
      Hashing.hex(Hashing.sha256(publicKey)).substring(0, 16).toUpperCase();
}

/// Kept for explicit header probing without decoding payloads (used by UI).
KeyMode? probeKeyMode(Uint8List containerBytes) => ContainerCodec.probe(containerBytes)?.keyMode;