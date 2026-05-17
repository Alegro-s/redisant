import 'dart:typed_data';

bool looksLikeEncryptedNexusCore(Uint8List bytes) {
  if (bytes.length < 8) return false;
  return bytes[0] == 0x4e && bytes[1] == 0x58; // 'NX'
}

Future<Uint8List?> decryptNexusCoreIfNeeded(Uint8List raw) async {
  if (!looksLikeEncryptedNexusCore(raw)) return raw;
  return null;
}
