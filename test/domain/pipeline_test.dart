import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stegshare/core/container/container_codec.dart';
import 'package:stegshare/core/container/container_format.dart';
import 'package:stegshare/core/crypto/kdf.dart';
import 'package:stegshare/core/errors.dart';
import 'package:stegshare/core/steganography/image_codec.dart';
import 'package:stegshare/core/steganography/stego_image.dart';
import 'package:stegshare/core/util/cancellation.dart';
import 'package:stegshare/domain/models.dart';
import 'package:stegshare/domain/steg_pipeline.dart';

const fastKdf = KdfParams(algorithm: KdfAlgorithm.argon2id, memoryKiB: 256, iterations: 1, parallelism: 1);

Uint8List coverPng(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < rgba.length; i++) {
    rgba[i] = (i * 13) & 0xFF;
  }
  return StegoImageCodec.encodePng(StegoImage(width: w, height: h, rgba: rgba));
}

void noProgress(double f, String s) {}

void main() {
  test('full hide -> png -> extract with password and scatter key', () async {
    final cover = coverPng(200, 150);
    final job = HideJob(
      imageBytes: cover,
      items: [
        HidePayloadItem.text(name: 'note.txt', data: Uint8List.fromList(utf8.encode('hello stego'))),
        HidePayloadItem.text(name: 'two.txt', data: Uint8List.fromList(utf8.encode('second'))),
      ],
      spec: const EncryptionSpec.password('pw', kdf: fastKdf),
      scatterKey: 'scatter',
    );
    final png = await StegPipeline.hide(job, noProgress, CancellationToken());
    final r = await StegPipeline.extract(
        ExtractJob(imageBytes: png, password: 'pw', scatterKey: 'scatter'), noProgress, CancellationToken());
    expect(r.items.map((i) => i.asText), ['hello stego', 'second']);
    expect(r.keyMode, KeyMode.password);

    expect(
        () => StegPipeline.extract(ExtractJob(imageBytes: png, password: 'pw'), noProgress, CancellationToken()),
        throwsA(isA<NoContainerFoundException>()));
    expect(
        () => StegPipeline.extract(
            ExtractJob(imageBytes: png, password: 'bad', scatterKey: 'scatter'), noProgress, CancellationToken()),
        throwsA(isA<DecryptionException>()));
  });

  test('clean image has no container; oversized payload rejected', () async {
    final cover = coverPng(40, 40);
    expect(() => StegPipeline.extract(ExtractJob(imageBytes: cover), noProgress, CancellationToken()),
        throwsA(isA<NoContainerFoundException>()));
    final job = HideJob(
      imageBytes: cover,
      items: [HidePayloadItem.text(name: 'big.txt', data: Uint8List.fromList(List.generate(5000, (i) => i & 0xFF)))],
      spec: const EncryptionSpec.none(),
      compress: false,
    );
    expect(() => StegPipeline.hide(job, noProgress, CancellationToken()), throwsA(isA<CapacityException>()));
  });

  test('inspect reports capacities', () async {
    final info = await StegPipeline.inspect(coverPng(100, 100), noProgress, CancellationToken());
    expect(info.width, 100);
    expect(info.capacitySequential, greaterThan(info.capacityKeyed));
  });
}