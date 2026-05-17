import 'dart:typed_data';

(int? width, int? height)? readPngIntrinsicSize(Uint8List bytes) {
  if (bytes.length < 24) return null;
  if (bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47) {
    return null;
  }
  int u32(int o) =>
      (bytes[o] & 0xFF) << 24 |
      (bytes[o + 1] & 0xFF) << 16 |
      (bytes[o + 2] & 0xFF) << 8 |
      (bytes[o + 3] & 0xFF);
  return (u32(16), u32(20));
}
