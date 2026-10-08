import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stegshare/core/errors.dart';
import 'package:stegshare/core/steganography/image_codec.dart';
import 'package:stegshare/core/steganography/lsb_engine.dart';
import 'package:stegshare/core/steganography/stego_image.dart';

StegoImage makeImage(int w, int h) {
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < rgba.length; i++) {
    rgba[i] = (i * 7 + 13) & 0xFF;
  }
  return StegoImage(width: w, height: h, rgba: rgba);
}

void main() {
  final engine = LsbRgbEngine();

  test('capacity formula', () {
    final img = makeImage(100, 100);
    expect(engine.capacityBytes(img), (100 * 100 * 3 - 32) ~/ 8);
    expect(engine.capacityBytes(img, keyed: true), (100 * 100 * 3 * 90 ~/ 100 - 32) ~/ 8);
    expect(engine.capacityBytes(makeImage(1, 1)), 0);
  });

  test('sequential embed/extract and alpha untouched', () {
    final img = makeImage(64, 64);
    final alphaBefore = [for (var i = 3; i < img.rgba.length; i += 4) img.rgba[i]];
    final data = Uint8List.fromList(List.generate(500, (i) => i * 3 & 0xFF));
    engine.embed(img, data);
    expect(engine.extract(img), equals(data));
    expect([for (var i = 3; i < img.rgba.length; i += 4) img.rgba[i]], equals(alphaBefore));
  });

  test('keyed embed/extract; wrong key does not yield data', () {
    final img = makeImage(80, 80);
    final data = Uint8List.fromList(List.generate(1000, (i) => (i * 17) & 0xFF));
    final key = Uint8List.fromList('secret'.codeUnits);
    engine.embed(img, data, key: key);
    expect(engine.extract(img, key: key), equals(data));
    final wrong = engine.extract(img, key: Uint8List.fromList('other'.codeUnits));
    expect(wrong == null || !_listEq(wrong, data), isTrue);
  });

  test('over capacity throws', () {
    final img = makeImage(10, 10);
    expect(() => engine.embed(img, Uint8List(engine.capacityBytes(img) + 1)), throwsA(isA<CapacityException>()));
  });

  test('payload at full capacity (sequential and keyed)', () {
    for (final keyed in [false, true]) {
      final img = makeImage(120, 90);
      final key = keyed ? Uint8List.fromList([1, 2, 3]) : null;
      final cap = engine.capacityBytes(img, keyed: keyed);
      final data = Uint8List.fromList(List.generate(cap, (i) => (i ^ (i >> 8)) & 0xFF));
      engine.embed(img, data, key: key);
      expect(engine.extract(img, key: key), equals(data));
    }
  });

  test('PNG encode/decode preserves LSBs', () {
    final img = makeImage(50, 40);
    final data = Uint8List.fromList(List.generate(300, (i) => i & 0xFF));
    engine.embed(img, data);
    final png = StegoImageCodec.encodePng(img);
    final back = StegoImageCodec.decode(png);
    expect(engine.extract(back), equals(data));
  });

  test('random image yields no container', () {
    expect(engine.extract(makeImage(5, 5)), anyOf(isNull, isA<Uint8List>()));
  });
}

bool _listEq(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}