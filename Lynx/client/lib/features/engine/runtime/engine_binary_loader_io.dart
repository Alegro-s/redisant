import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nexus_engine_manifest.dart';
import 'lynx_engine_format.dart';

export 'nexus_engine_manifest.dart';
export 'lynx_engine_format.dart';

const String kNexusEngineManifestPath = '/engine/manifest';
const String kLynxEngineFileExtension = '.lynxengine';

const _prefsEnginePath = 'nexus_engine_lib_path';
const _prefsEngineVer = 'nexus_engine_lib_version';
const _prefsLynxEnginePath = 'lynx_engine_lib_path';
const _prefsLynxEngineVer = 'lynx_engine_lib_version';

Future<String?> _lynxEnginesRootDir() async {
  if (kIsWeb) return null;
  final local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    return p.join(local, 'Lynx', 'engines');
  }
  final support = await getApplicationSupportDirectory();
  return p.join(support.path, 'lynx_engines');
}

Future<String?> _installUnpackedEngine({
  required LynxEngineUnpackResult unpacked,
  required String version,
}) async {
  final root = await _lynxEnginesRootDir();
  final plat = _artifactPlatformKey();
  final libName = _libraryFileName();
  if (root == null || plat == null || libName == null) return null;
  if (unpacked.manifest.platform != plat) return null;

  final cacheDir = p.join(root, version, plat);
  await Directory(cacheDir).create(recursive: true);
  final targetLib = p.join(cacheDir, libName);
  await File(targetLib).writeAsBytes(unpacked.libraryBytes);
  await _extractEngineExtras(unpacked.plainPayload, cacheDir);
  await _persistEnginePrefs(targetLib, version, lynxNative: true);
  return File(targetLib).absolute.path;
}

Future<void> _extractEngineExtras(Uint8List plainZip, String cacheDir) async {
  try {
    final archive = ZipDecoder().decodeBytes(plainZip);
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (!f.name.startsWith('extras/')) continue;
      final rel = f.name.substring('extras/'.length);
      if (rel.isEmpty) continue;
      final target = p.join(cacheDir, rel.replaceAll('/', p.separator));
      await Directory(p.dirname(target)).create(recursive: true);
      await File(target).writeAsBytes(f.content as List<int>);
    }
  } catch (_) {}
}

/// E22c — LynxEngine.exe из установленного `.lynxengine` pack.
Future<String?> resolveInstalledLynxEngineExecutable({String? preferredVersion}) async {
  if (kIsWeb) return null;
  final root = await _lynxEnginesRootDir();
  final plat = _artifactPlatformKey();
  if (root == null || plat == null) return null;
  final versions = await listInstalledLynxEngineVersions();
  final ordered = <String>[];
  if (preferredVersion != null && preferredVersion.isNotEmpty) {
    ordered.add(preferredVersion);
  }
  for (final v in versions) {
    if (!ordered.contains(v)) ordered.add(v);
  }
  for (final ver in ordered) {
    for (final rel in ['shell/LynxEngine.exe', 'LynxEngine.exe']) {
      final candidate = p.join(root, ver, plat, rel);
      if (await File(candidate).exists()) return candidate;
    }
  }
  return null;
}

/// Installs Lynx Engine from a local `.lynxengine` file (Launcher / Hub).
Future<String?> installLynxEngineFromFile(String filePath) async {
  if (kIsWeb) return null;
  final f = File(filePath);
  if (!await f.exists()) return null;
  final bytes = await f.readAsBytes();
  return installLynxEngineFromBytes(bytes);
}

Future<String?> installLynxEngineFromBytes(Uint8List bytes) async {
  if (kIsWeb) return null;
  final unpacked = await unpackLynxEngineBytes(bytes);
  if (unpacked == null) return null;
  return _installUnpackedEngine(
    unpacked: unpacked,
    version: unpacked.manifest.version,
  );
}

Future<List<String>> listInstalledLynxEngineVersions() async {
  if (kIsWeb) return const [];
  final root = await _lynxEnginesRootDir();
  if (root == null || !await Directory(root).exists()) return const [];
  final out = <String>[];
  await for (final verDir in Directory(root).list()) {
    if (verDir is! Directory) continue;
    final name = p.basename(verDir.path);
    final plat = _artifactPlatformKey();
    if (plat == null) continue;
    final lib = File(p.join(verDir.path, plat, _libraryFileName() ?? 'engine.dll'));
    if (await lib.exists()) out.add(name);
  }
  out.sort((a, b) => b.compareTo(a));
  return out;
}

Future<bool> removeInstalledLynxEngineVersion(String version) async {
  if (kIsWeb) return false;
  final root = await _lynxEnginesRootDir();
  if (root == null) return false;
  final dir = Directory(p.join(root, version));
  if (!await dir.exists()) return false;
  await dir.delete(recursive: true);
  return true;
}

Future<String?> _tryInstallFromLynxEngineBlob(Uint8List raw) async {
  if (!looksLikeLynxEngineFile(raw)) return null;
  return installLynxEngineFromBytes(raw);
}

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

    final lynxPath = await _tryInstallFromLynxEngineBlob(plain);
    if (lynxPath != null) return lynxPath;

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

    final lynxRoot = await _lynxEnginesRootDir();
    final cacheDir = lynxRoot != null
        ? p.join(lynxRoot, version, plat)
        : p.join((await getApplicationSupportDirectory()).path, 'nexus_engine', version);
    final targetLib = p.join(cacheDir, libName);
    final cached = File(targetLib);
    if (await cached.exists()) {
      if (expectSha != null && expectSha.isNotEmpty) {
        final bad = await _verifySha256(cached, expectSha);
        if (bad != null) {
          await cached.delete();
        } else {
          await _persistEnginePrefs(targetLib, version, lynxNative: lynxRoot != null);
          return cached.absolute.path;
        }
      } else {
        await _persistEnginePrefs(targetLib, version, lynxNative: lynxRoot != null);
        return cached.absolute.path;
      }
    }

    final bin = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    if (bin.statusCode != 200 || bin.data == null) return null;
    final bytes = Uint8List.fromList(bin.data!);

    if (looksLikeLynxEngineFile(bytes) || url.toLowerCase().endsWith('.lynxengine')) {
      return installLynxEngineFromBytes(bytes);
    }

    await Directory(cacheDir).create(recursive: true);

    if (url.toLowerCase().endsWith('.zip') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4b &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04)) {
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
    await _persistEnginePrefs(targetLib, version, lynxNative: lynxRoot != null);
    return outFile.absolute.path;
  } catch (e, st) {
    debugPrint('ensureEngineBinary: $e\n$st');
    return null;
  }
}

Future<void> _persistEnginePrefs(
  String absLibPath,
  String version, {
  bool lynxNative = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (lynxNative) {
    await prefs.setString(_prefsLynxEnginePath, absLibPath);
    await prefs.setString(_prefsLynxEngineVer, version);
  }
  await prefs.setString(_prefsEnginePath, absLibPath);
  await prefs.setString(_prefsEngineVer, version);
}

Future<String?> getLastCachedEngineLibraryPath() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in [_prefsLynxEnginePath, _prefsEnginePath]) {
    final path = prefs.getString(key);
    if (path != null && path.isNotEmpty && await File(path).exists()) {
      return path;
    }
  }
  return null;
}

/// Последняя установленная версия Lynx Engine на диске (без API).
Future<String?> resolveLatestInstalledEngineLibrary() async {
  final cached = await getLastCachedEngineLibraryPath();
  if (cached != null) return cached;

  final versions = await listInstalledLynxEngineVersions();
  if (versions.isEmpty) return null;

  final root = await _lynxEnginesRootDir();
  final plat = _artifactPlatformKey();
  final libName = _libraryFileName();
  if (root == null || plat == null || libName == null) return null;

  for (final version in versions) {
    final lib = File(p.join(root, version, plat, libName));
    if (await lib.exists()) {
      final abs = lib.absolute.path;
      await _persistEnginePrefs(abs, version, lynxNative: true);
      return abs;
    }
  }
  return null;
}

Future<String?> getInstalledEngineVersionLabel() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in [_prefsLynxEngineVer, _prefsEngineVer]) {
    final v = prefs.getString(key);
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
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
