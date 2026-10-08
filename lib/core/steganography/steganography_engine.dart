import 'dart:typed_data';

import '../util/cancellation.dart';
import 'stego_image.dart';

/// Pluggable embedding algorithm. Implementations must be pure CPU work so
/// they can run inside isolates. Nothing here is "invisible": LSB embedding is
/// detectable by steganalysis and destroyed by lossy re-encoding.
abstract class SteganographyEngine {
  String get id;

  /// Max payload bytes for this image (keyed scattering reserves headroom).
  int capacityBytes(StegoImage image, {bool keyed = false});

  void embed(
    StegoImage image,
    Uint8List data, {
    Uint8List? key,
    ProgressFn? onProgress,
    CancellationToken? token,
  });

  /// Returns null when no plausible stream is present.
  Uint8List? extract(
    StegoImage image, {
    Uint8List? key,
    ProgressFn? onProgress,
    CancellationToken? token,
  });
}