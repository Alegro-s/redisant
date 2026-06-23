import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

const String kLynxCartExtension = '.lynxcart';
const String kLynxCartMagic = 'LYNXCART1';

/// Манифест внутри `.lynxcart` (ZIP).
class LynxCartManifest {
  LynxCartManifest({
    required this.title,
    this.format = 'lynx_cart',
    this.version = 1,
    this.mainScript = 'main.lua',
    this.startupSceneId = 'main',
    this.designWidth = 480,
    this.designHeight = 272,
    this.tier = 'free_to_play',
    this.tags = const [],
    this.cartId,
  });

  final String format;
  final int version;
  final String title;
  final String mainScript;
  final String startupSceneId;
  final double designWidth;
  final double designHeight;
  final String tier;
  final List<String> tags;
  final String? cartId;

  Map<String, dynamic> toJson() => {
        'format': format,
        'version': version,
        'title': title,
        'mainScript': mainScript,
        'startupSceneId': startupSceneId,
        'designWidth': designWidth,
        'designHeight': designHeight,
        'tier': tier,
        'tags': tags,
        if (cartId != null) 'cartId': cartId,
      };

  factory LynxCartManifest.fromJson(Map<String, dynamic> json) {
    return LynxCartManifest(
      format: json['format'] as String? ?? 'lynx_cart',
      version: (json['version'] as num?)?.toInt() ?? 1,
      title: json['title'] as String? ?? 'Untitled',
      mainScript: json['mainScript'] as String? ?? 'main.lua',
      startupSceneId: json['startupSceneId'] as String? ?? 'main',
      designWidth: (json['designWidth'] as num?)?.toDouble() ?? 480,
      designHeight: (json['designHeight'] as num?)?.toDouble() ?? 272,
      tier: json['tier'] as String? ?? 'free_to_play',
      tags: (json['tags'] as List?)?.cast<String>() ?? const [],
      cartId: json['cartId'] as String?,
    );
  }
}

bool _excludeCartPath(String rel) {
  final n = p.normalize(rel).replaceAll('\\', '/');
  if (n == '.git' || n.startsWith('.git/')) return true;
  if (n.startsWith('.dart_tool/')) return true;
  if (n.startsWith('build/')) return true;
  return false;
}

Future<File> packProjectToLynxCart({
  required String projectRoot,
  required String outputPath,
  LynxCartManifest? manifest,
}) async {
  final projectJson = File(p.join(projectRoot, 'project.json'));
  if (!await projectJson.exists()) {
    throw StateError('project.json не найден: $projectRoot');
  }
  final pj = jsonDecode(await projectJson.readAsString()) as Map<String, dynamic>;
  final cloud = pj['cloudPublish'] as Map<String, dynamic>?;
  final cartManifest = manifest ??
      LynxCartManifest(
        title: pj['displayName'] as String? ?? 'Lynx Cart',
        startupSceneId: pj['startupSceneId'] as String? ?? 'main',
        designWidth: (pj['designWidth'] as num?)?.toDouble() ?? 480,
        designHeight: (pj['designHeight'] as num?)?.toDouble() ?? 272,
        tier: cloud?['tier'] as String? ?? 'free_to_play',
        tags: (cloud?['tags'] as List?)?.cast<String>() ?? const [],
        cartId: pj['projectId'] as String?,
      );

  final archive = Archive();
  final manifestBytes = utf8.encode(jsonEncode(cartManifest.toJson()));
  archive.addFile(ArchiveFile('cart.json', manifestBytes.length, manifestBytes));

  final rootDir = Directory(projectRoot);
  await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: projectRoot);
    if (_excludeCartPath(rel)) continue;
    final bytes = await entity.readAsBytes();
    archive.addFile(ArchiveFile(rel.replaceAll('\\', '/'), bytes.length, bytes));
  }

  final outPath = outputPath.endsWith(kLynxCartExtension)
      ? outputPath
      : '$outputPath$kLynxCartExtension';
  final out = File(outPath);
  await out.parent.create(recursive: true);
  final encoded = ZipEncoder().encode(archive);
  if (encoded == null) {
    throw StateError('Не удалось упаковать $kLynxCartExtension');
  }
  await out.writeAsBytes(encoded);
  return out;
}

Future<String> extractLynxCartToDirectory({
  required String cartFilePath,
  required String destDirectory,
}) async {
  final bytes = await File(cartFilePath).readAsBytes();
  return extractLynxCartBytes(bytes, destDirectory);
}

Future<String> extractLynxCartBytes(List<int> zipBytes, String destDirectory) async {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  final dest = Directory(destDirectory);
  if (await dest.exists()) {
    await dest.delete(recursive: true);
  }
  await dest.create(recursive: true);
  for (final file in archive) {
    if (!file.isFile) continue;
    final outPath = p.join(dest.path, file.name);
    await Directory(p.dirname(outPath)).create(recursive: true);
    await File(outPath).writeAsBytes(file.content as List<int>);
  }
  return dest.path;
}

Future<LynxCartManifest> readLynxCartManifest(String cartFilePath) async {
  final archive = ZipDecoder().decodeBytes(await File(cartFilePath).readAsBytes());
  for (final file in archive) {
    if (file.name == 'cart.json' && file.isFile) {
      final raw = utf8.decode(file.content as List<int>);
      return LynxCartManifest.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    }
  }
  throw StateError('cart.json не найден в $cartFilePath');
}
