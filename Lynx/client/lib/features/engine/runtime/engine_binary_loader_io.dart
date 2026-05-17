import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nexus_engine_manifest.dart';

export 'nexus_engine_manifest.dart';

const String kNexusEngineManifestPath = '/engine/manifest';

const _prefsEnginePath = 'nexus_engine_lib_path';
const _prefsEngineVer = 'nexus_engine_lib_version';

String? _artifactPlatformKey() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isLinux) return 'linux';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isAndroid) return 'android';
  return null;
}

String? _libraryFileName() {
  if (Platform.isWindows) return 'engine.dll';
  if (Platform.isLinux) return 'libengine.so';
  if (Platform.isMacOS) return 'libengine.dylib';
  if (Platform.isAndroid) return 'libengine.so';
  return null;
}

Map<String, dynamic>? _pickRelease(
  List<dynamic> releases,
  String? recommended, {
  String? preferredVersion,
}) {
  if (releases.isEmpty) return null;
  if (preferredVersion != null && preferredVersion.isNotEmpty) {
    for (final r in releases) {
      if (r is Map && r['version']?.toString() == preferredVersion) {
        return r.cast<String, dynamic>();
      }
    }
  }
  if (recommended != null && recommended.isNotEmpty) {
    for (final r in releases) {
      if (r is Map && r['version']?.toString() == recommended) {
        return r.cast<String, dynamic>();
      }
    }
  }
  final first = releases.first;
  return first is Map<String, dynamic>
      ? first
      : (first as Map).cast<String, dynamic>();
}

Future<NexusEngineManifestSnapshot?> fetchEngineManifestSnapshot(Dio dio) async {
  if (kIsWeb) return null;
  try {
    final res = await dio.get<Map<String, dynamic>>(kNexusEngineManifestPath);
    if (res.statusCode != 200 || res.data == null) return null;
    final data = res.data!;
    final raw = data['releases'];
    if (raw is! List) {
      return NexusEngineManifestSnapshot(releases: const [], recommendedVersion: data['recommended_version']?.toString(), source: data['source']?.toString());
    }
    final list = <Map<String, dynamic>>[];
    for (final r in raw) {
      if (r is Map<String, dynamic>) {
        list.add(r);
      } else if (r is Map) {
        list.add(r.cast<String, dynamic>());
      }
    }
    return NexusEngineManifestSnapshot(
      releases: list,
      recommendedVersion: data['recommended_version']?.toString(),
      source: data['source']?.toString(),
    );
  } catch (e, st) {
    debugPrint('fetchEngineManifestSnapshot: $e\n$st');
    return null;
  }
}

bool engineReleaseSupportsCurrentHost(Map<String, dynamic> release) {
  if (kIsWeb) return false;
  final plat = _artifactPlatformKey();
  if (plat == null) return false;
  return _artifactForPlatform(release, plat) != null;
}

Map<String, dynamic>? _artifactForPlatform(
  Map<String, dynamic> release,
  String plat,
) {
  final arts = release['artifacts'];
  if (arts is! Map) return null;
  final a = arts[plat];
  if (a is! Map) return null;
  return a.cast<String, dynamic>();
}

Future<String?> _verifySha256(File f, String expectedHex) async {
  final digest = await sha256.bind(f.openRead()).first;
  final hex = digest.toString();
  if (hex.toLowerCase() != expectedHex.toLowerCase().trim()) {
    return 'sha256 mismatch';
  }
  return null;
}

Future<Uint8List?> _decryptEngineBlob(Uint8List body, String keyB64) async {
  if (body.length < 12 + 16) return null;
  try {
    final keyBytes = base64Decode(keyB64.trim());
    if (keyBytes.length != 32) return null;
    final nonce = body.sublist(0, 12);
    final combined = body.sublist(12);
    if (combined.length < 16) return null;
    final cipherText = combined.sublist(0, combined.length - 16);
    final mac = Mac(combined.sublist(combined.length - 16));
    final plain = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: SecretKey(keyBytes),
    );
    return Uint8List.fromList(plain);
  } catch (e, st) {
    debugPrint('_decryptEngineBlob: $e\n$st');
    return null;
  }
}

bool _isPlaceholderEngineJson(List<int> bytes) {
  if (bytes.length < 8) return false;
  final s = utf8.decode(bytes, allowMalformed: true).trimLeft();
  return s.startsWith('{') && s.contains('"placeholder"');
}

Future<String?> _ensureFromEncryptedSession(
  Dio dio,
  String version,
  String libName,
  String plat,
  Map<String, dynamic> release,
) async {
  try {
    final session = await dio.post<Map<String, dynamic>>(
      '/me/engine/session',
      data: {'version': version},
    );
    if (session.statusCode != 200 || session.data == null) return null;
    final downloadUrl = session.data!['download_url']?.toString();
    final keyB64 = session.data!['decryption_key_b64']?.toString();
    if (downloadUrl == null ||
        downloadUrl.isEmpty ||
        keyB64 == null ||
        keyB64.isEmpty) {
      return null;
    }

    final bin = await dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    if (bin.statusCode != 200 || bin.data == null) return null;
    final raw = Uint8List.fromList(bin.data!);
    final plain = await _decryptEngineBlob(raw, keyB64);
    if (plain == null) return null;
    if (_isPlaceholderEngineJson(plain)) return null;

    final support = await getApplicationSupportDirectory();
    final cacheDir = p.join(support.path, 'nexus_engine', version);
    final targetLib = p.join(cacheDir, libName);
    await Directory(cacheDir).create(recursive: true);

    final art = _artifactForPlatform(release, plat);
    final expectSha = art?['sha256']?.toString();

    if (plain.length >= 4 &&
        plain[0] == 0x50 &&
        plain[1] == 0x4b &&
        plain[2] == 0x03 &&
        plain[3] == 0x04) {
      final archive = ZipDecoder().decodeBytes(plain);
      ArchiveFile? hit;
      for (final f in archive.files) {
        if (f.isFile && p.basename(f.name) == libName) {
          hit = f;
          break;
        }
      }
      if (hit == null) return null;
      await File(targetLib).writeAsBytes(hit.content as List<int>);
    } else {
      await File(targetLib).writeAsBytes(plain);
    }

    final outFile = File(targetLib);
    if (!await outFile.exists()) return null;
    if (expectSha != null && expectSha.isNotEmpty) {
      final bad = await _verifySha256(outFile, expectSha);
      if (bad != null) {
        await outFile.delete();
        return null;
      }
    }
    await _persistEnginePrefs(targetLib, version);
    return outFile.absolute.path;
  } catch (e, st) {
    debugPrint('_ensureFromEncryptedSession: $e\n$st');
    return null;
  }
}

Future<String?> ensureEngineBinary(
  Dio dio, {
  String? preferredVersion,
}) async {
  if (kIsWeb) return null;
  final plat = _artifactPlatformKey();
  final libName = _libraryFileName();
  if (plat == null || libName == null) return null;

  try {
    final res = await dio.get<Map<String, dynamic>>('/engine/manifest');
    if (res.statusCode != 200 || res.data == null) return null;
    final data = res.data!;
    final releases = data['releases'];
    if (releases is! List || releases.isEmpty) return null;
    final rec = data['recommended_version']?.toString();
    final rel = _pickRelease(releases, rec, preferredVersion: preferredVersion);
    if (rel == null) return null;
    final version = rel['version']?.toString() ?? 'unknown';

    final encPath = await _ensureFromEncryptedSession(
      dio,
      version,
      libName,
      plat,
      rel,
    );
    if (encPath != null) return encPath;

    final art = _artifactForPlatform(rel, plat);
    if (art == null) return null;
    final url = art['url']?.toString();
    if (url == null || url.isEmpty) return null;
    final expectSha = art['sha256']?.toString();

    final support = await getApplicationSupportDirectory();
    final cacheDir = p.join(support.path, 'nexus_engine', version);
    final targetLib = p.join(cacheDir, libName);
    final cached = File(targetLib);
    if (await cached.exists()) {
      if (expectSha != null && expectSha.isNotEmpty) {
        final bad = await _verifySha256(cached, expectSha);
        if (bad != null) {
          await cached.delete();
        } else {
          await _persistEnginePrefs(targetLib, version);
          return cached.absolute.path;
        }
      } else {
        await _persistEnginePrefs(targetLib, version);
        return cached.absolute.path;
      }
    }

    await Directory(cacheDir).create(recursive: true);
    final bin = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    if (bin.statusCode != 200 || bin.data == null) return null;
    final bytes = bin.data!;

    if (url.toLowerCase().endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? hit;
      for (final f in archive.files) {
        if (f.isFile && p.basename(f.name) == libName) {
          hit = f;
          break;
        }
      }
      if (hit == null) return null;
      final out = File(targetLib);
      await out.writeAsBytes(hit.content as List<int>);
    } else {
      await File(targetLib).writeAsBytes(bytes);
    }

    final outFile = File(targetLib);
    if (!await outFile.exists()) return null;
    if (expectSha != null && expectSha.isNotEmpty) {
      final bad = await _verifySha256(outFile, expectSha);
      if (bad != null) {
        await outFile.delete();
        return null;
      }
    }
    await _persistEnginePrefs(targetLib, version);
    return outFile.absolute.path;
  } catch (e, st) {
    debugPrint('ensureEngineBinary: $e\n$st');
    return null;
  }
}

Future<void> _persistEnginePrefs(String absLibPath, String version) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_prefsEnginePath, absLibPath);
  await p.setString(_prefsEngineVer, version);
}

Future<String?> getLastCachedEngineLibraryPath() async {
  final prefs = await SharedPreferences.getInstance();
  final path = prefs.getString(_prefsEnginePath);
  if (path == null || path.isEmpty) return null;
  if (await File(path).exists()) return path;
  return null;
}

Future<String?> getInstalledEngineVersionLabel() async {
  final prefs = await SharedPreferences.getInstance();
  final v = prefs.getString(_prefsEngineVer);
  if (v == null || v.isEmpty) return null;
  return v;
}

Future<String?> fetchRecommendedEngineVersion(Dio dio) async {
  if (kIsWeb) return null;
  try {
    final res = await dio.get<Map<String, dynamic>>(kNexusEngineManifestPath);
    if (res.statusCode != 200 || res.data == null) return null;
    final rec = res.data!['recommended_version']?.toString();
    return rec != null && rec.isNotEmpty ? rec : null;
  } catch (_) {
    return null;
  }
}
