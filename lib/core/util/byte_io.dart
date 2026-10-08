import 'dart:typed_data';

import '../errors.dart';

/// Big-endian binary writer.
class ByteWriter {
  final BytesBuilder _b = BytesBuilder(copy: false);

  int get length => _b.length;

  void u8(int v) {
    if (v < 0 || v > 0xFF) throw ArgumentError.value(v, 'u8');
    _b.addByte(v);
  }

  void u16(int v) {
    if (v < 0 || v > 0xFFFF) throw ArgumentError.value(v, 'u16');
    _b.addByte(v >> 8);
    _b.addByte(v & 0xFF);
  }

  void u32(int v) {
    if (v < 0 || v > 0xFFFFFFFF) throw ArgumentError.value(v, 'u32');
    _b.addByte((v >> 24) & 0xFF);
    _b.addByte((v >> 16) & 0xFF);
    _b.addByte((v >> 8) & 0xFF);
    _b.addByte(v & 0xFF);
  }

  void bytes(List<int> data) => _b.add(data);

  Uint8List toBytes() => _b.toBytes();
}

/// Bounds-checked big-endian reader. Never trusts lengths coming from data.
class ByteReader {
  final Uint8List data;
  int offset;

  ByteReader(this.data, [this.offset = 0]);

  int get remaining => data.length - offset;
  bool get isAtEnd => offset >= data.length;

  void _need(int n) {
    if (n < 0 || offset + n > data.length) {
      throw const ContainerFormatException('Unexpected end of data.');
    }
  }

  int u8() {
    _need(1);
    return data[offset++];
  }

  int u16() {
    _need(2);
    final v = (data[offset] << 8) | data[offset + 1];
    offset += 2;
    return v;
  }

  int u32() {
    _need(4);
    final v = (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
    offset += 4;
    return v;
  }

  Uint8List bytes(int n) {
    _need(n);
    final r = Uint8List.sublistView(data, offset, offset + n);
    offset += n;
    return r;
  }
}