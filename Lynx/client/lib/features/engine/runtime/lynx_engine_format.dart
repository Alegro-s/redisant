import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

/// Proprietary Lynx Engine pack format (`.lynxengine`).
class LynxEnginePackManifest {
  LynxEnginePackManifest({
    required this.version,
    required this.platform,
    required this.libraryName,
    required this.lynxCoreVersion,
    required this.coreApiVersion,
    required this.payloadSha256,
  });

  final String version;
  final String platform;
  final String libraryName;
  final String lynxCoreVersion;
  final int coreApiVersion;
  final String payloadSha256;

  factory LynxEnginePackManifest.fromJson(Map<String, dynamic> json) {
    return LynxEnginePackManifest(
      version: json['version']?.toString() ?? 'unknown',
      platform: json['platform']?.toString() ?? 'windows',
      libraryName: json['libraryName']?.toString() ?? 'engine.dll',
      lynxCoreVersion: json['lynxCoreVersion']?.toString() ?? '0.0.0',
      coreApiVersion: (json['coreApiVersion'] as num?)?.toInt() ?? 1,
      payloadSha256: json['payloadSha256']?.toString() ?? '',
    );
  }
}

class LynxEngineUnpackResult {
  LynxEngineUnpackResult({
    required this.manifest,
    required this.libraryBytes,
    required this.libraryName,
    required this.plainPayload,
  });

  final LynxEnginePackManifest manifest;
  final Uint8List libraryBytes;
  final String libraryName;
  /// Decrypted inner zip (engine.dll + optional extras/).
  final Uint8List plainPayload;
}

const _magic = [0x4c, 0x59, 0x4e, 0x58, 0x45, 0x4e, 0x47, 0x31]; // LYNXENG1
const _masterSeed = 'LynxEnginePack:v1:PO-Lynx-2026';

List<int> _derivePackKey(String version, String platform) {
  final root = crypto.sha256.convert(utf8.encode(_masterSeed)).bytes;
  final h = crypto.Hmac(crypto.sha256, root);
  return h.convert(utf8.encode('$version:$platform')).bytes;
}

Future<Uint8List?> _decryptAesGcm(Uint8List body, List<int> keyBytes) async {
  if (body.length < 12 + 16 || keyBytes.length != 32) return null;
  try {
    final nonce = body.sublist(0, 12);
    final combined = body.sublist(12);
    final cipherText = combined.sublist(0, combined.length - 16);
    final mac = Mac(combined.sublist(combined.length - 16));
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: SecretKey(keyBytes),
    );
    return Uint8List.fromList(plain);
  } catch (_) {
    return null;
  }
}

/// Parses and decrypts a `.lynxengine` blob. Only Lynx Launcher/Editor knows the key.
Future<LynxEngineUnpackResult?> unpackLynxEngineBytes(Uint8List bytes) async {
  if (bytes.length < 16) return null;
  for (var i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return null;
  }
  final schema = bytes.buffer.asByteData().getUint32(8, Endian.little);
  if (schema != 1) return null;
  final mlen = bytes.buffer.asByteData().getUint32(12, Endian.little);
  if (bytes.length < 16 + mlen) return null;
  Map<String, dynamic> manifestJson;
  try {
    manifestJson = jsonDecode(utf8.decode(bytes.sublist(16, 16 + mlen)))
        as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
  final manifest = LynxEnginePackManifest.fromJson(manifestJson);
  final encrypted = bytes.sublist(16 + mlen);
  final key = _derivePackKey(manifest.version, manifest.platform);
  final plain = await _decryptAesGcm(encrypted, key);
  if (plain == null) return null;

  if (manifest.payloadSha256.isNotEmpty) {
    final got = crypto.sha256.convert(plain).toString();
    if (got.toLowerCase() != manifest.payloadSha256.toLowerCase()) {
      return null;
    }
  }

  ArchiveFile? libHit;
  try {
    final archive = ZipDecoder().decodeBytes(plain);
    for (final f in archive.files) {
      if (f.isFile && f.name.endsWith(manifest.libraryName)) {
        libHit = f;
        break;
      }
    }
    if (libHit == null) {
      for (final f in archive.files) {
        if (f.isFile && f.name.split('/').last == manifest.libraryName) {
          libHit = f;
          break;
        }
      }
    }
  } catch (_) {
    return null;
  }
  if (libHit == null) return null;
  return LynxEngineUnpackResult(
    manifest: manifest,
    libraryBytes: Uint8List.fromList(libHit.content as List<int>),
    libraryName: manifest.libraryName,
    plainPayload: plain,
  );
}

bool looksLikeLynxEngineFile(Uint8List bytes) {
  if (bytes.length < _magic.length) return false;
  for (var i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return false;
  }
  return true;
}
