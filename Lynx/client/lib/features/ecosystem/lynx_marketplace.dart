import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../engine/models/engine_models.dart';
import '../engine/runtime/lynx_project_templates.dart';
import '../plugins/lynx_plugin_manifest.dart';
import 'lynx_cloud_marketplace.dart';

/// Пакет из каталога Lynx Cloud / Hub (`apiVersion: 1`).
class LynxMarketplaceItem {
  LynxMarketplaceItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    this.version,
    this.engineMinVersion,
    this.price,
    this.packageUrl,
    this.templateId,
    this.pluginId,
    this.builtin = false,
    this.description,
    this.author,
    this.rating,
    this.imageUrl,
    this.tags = const [],
  });

  final String id;
  final String kind;
  final String title;
  final String category;
  final String? version;
  final String? engineMinVersion;
  final double? price;
  final String? packageUrl;
  final String? templateId;
  final String? pluginId;
  final bool builtin;
  final String? description;
  final String? author;
  final double? rating;
  final String? imageUrl;
  final List<String> tags;

  factory LynxMarketplaceItem.fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    return LynxMarketplaceItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'asset_pack',
      title: json['title'] as String? ?? 'Без названия',
      category: (json['category'] as String? ?? 'tools').toLowerCase(),
      version: json['version'] as String?,
      engineMinVersion: json['engineMinVersion'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      packageUrl: json['packageUrl'] as String?,
      templateId: json['templateId'] as String?,
      pluginId: json['pluginId'] as String? ?? json['id'] as String?,
      builtin: json['builtin'] as bool? ?? false,
      description: json['description'] as String?,
      author: json['author'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      imageUrl: json['image'] as String? ?? json['thumbnail'] as String?,
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'title': title,
        'category': category,
        if (version != null) 'version': version,
        if (engineMinVersion != null) 'engineMinVersion': engineMinVersion,
        if (price != null) 'price': price,
        if (packageUrl != null) 'packageUrl': packageUrl,
        if (templateId != null) 'templateId': templateId,
        if (pluginId != null) 'pluginId': pluginId,
        'builtin': builtin,
        if (description != null) 'description': description,
        if (author != null) 'author': author,
        if (rating != null) 'rating': rating,
        if (imageUrl != null) 'image': imageUrl,
        if (tags.isNotEmpty) 'tags': tags,
      };
}

class LynxMarketplaceCatalog {
  LynxMarketplaceCatalog({
    required this.apiVersion,
    required this.items,
    this.updatedAt,
  });

  final int apiVersion;
  final List<LynxMarketplaceItem> items;
  final String? updatedAt;

  factory LynxMarketplaceCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? [];
    return LynxMarketplaceCatalog(
      apiVersion: json['apiVersion'] as int? ?? 1,
      updatedAt: json['updatedAt'] as String?,
      items: raw
          .whereType<Map>()
          .map((e) => LynxMarketplaceItem.fromJson(Map<String, dynamic>.from(e)))
          .where((i) => i.id.isNotEmpty)
          .toList(),
    );
  }
}

class LynxMarketplaceInstallResult {
  const LynxMarketplaceInstallResult({this.ok = true, this.message = ''});
  final bool ok;
  final String message;
}

/// Загрузка каталога и установка в локальный проект (волна 7).
class LynxMarketplace {
  static const defaultBundledCatalogAsset =
      'assets/marketplace/default_catalog.json';

  /// Каталог: Cloud API (если [cloudDio] задан) → URL → bundled.
  static Future<LynxMarketplaceCatalog> fetchCatalog(
    String url, {
    Dio? cloudDio,
  }) async {
    if (cloudDio != null) {
      try {
        return await LynxCloudMarketplace(cloudDio).fetchCatalog();
      } catch (_) {
        // fallback ниже
      }
    }
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return _loadBundled();
    }
    if (trimmed.startsWith('asset://')) {
      return _loadBundled();
    }
    try {
      final r = await Dio().get<dynamic>(trimmed);
      return _parseResponse(r.data);
    } catch (_) {
      return _loadBundled();
    }
  }

  static Future<LynxMarketplaceCatalog> _loadBundled() async {
    final raw = await rootBundle.loadString(defaultBundledCatalogAsset);
    return LynxMarketplaceCatalog.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  static LynxMarketplaceCatalog _parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('items')) {
        return LynxMarketplaceCatalog.fromJson(data);
      }
      if (data['items'] is List) {
        return LynxMarketplaceCatalog.fromJson(data);
      }
    }
    if (data is Map) {
      return LynxMarketplaceCatalog.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is List) {
      return LynxMarketplaceCatalog(
        apiVersion: 1,
        items: data
            .whereType<Map>()
            .map((e) => LynxMarketplaceItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    }
    return LynxMarketplaceCatalog(apiVersion: 1, items: []);
  }

  /// Установка пакета в `projectRoot` (локальная папка с `project.json`).
  static Future<LynxMarketplaceInstallResult> installIntoProject({
    required String projectRoot,
    required LynxMarketplaceItem item,
    required String repoRoot,
    Dio? cloudDio,
  }) async {
    final root = p.normalize(projectRoot);
    final pj = File(p.join(root, 'project.json'));
    if (!await pj.exists()) {
      return const LynxMarketplaceInstallResult(
        ok: false,
        message: 'В папке нет project.json — выберите корень проекта Lynx.',
      );
    }

    if (cloudDio != null && !item.builtin) {
      final claim = await LynxCloudMarketplace(cloudDio).claimItem(item.id);
      if (!claim.ok) {
        return LynxMarketplaceInstallResult(ok: false, message: claim.message);
      }
    }

    switch (item.kind) {
      case 'plugin':
        return _installPlugin(root, item, repoRoot, cloudDio: cloudDio);
      case 'template':
        return LynxMarketplaceInstallResult(
          ok: false,
          message:
              'Шаблон «${item.title}» создаёт новый проект — используйте «Проекты» → Создать.',
        );
      case 'asset_pack':
        return _installAssetPack(root, item);
      case 'engine_core':
        return LynxMarketplaceInstallResult(
          ok: true,
          message: 'Ядро ${item.title} ${item.version ?? ""} — скачайте с Lynx Hub → Download.',
        );
      default:
        return LynxMarketplaceInstallResult(
          ok: false,
          message: 'Неизвестный тип пакета: ${item.kind}',
        );
    }
  }

  static Future<LynxMarketplaceInstallResult> _installPlugin(
    String projectRoot,
    LynxMarketplaceItem item,
    String repoRoot, {
    Dio? cloudDio,
  }) async {
    final pluginId = item.pluginId ?? item.id;
    if (!item.builtin) {
      String? err;
      if (cloudDio != null) {
        err = await _downloadCloudZipToPlugins(projectRoot, pluginId, cloudDio);
      }
      if (err != null &&
          item.packageUrl != null &&
          item.packageUrl!.isNotEmpty) {
        err = await _downloadZipToPlugins(
          projectRoot,
          item.packageUrl!,
          pluginId,
        );
      }
      if (err != null && !item.builtin) {
        return LynxMarketplaceInstallResult(ok: false, message: err);
      }
    }
    if (item.builtin) {
      final src = Directory(p.join(repoRoot, 'plugins', pluginId));
      final dst = Directory(p.join(projectRoot, 'plugins', pluginId));
      if (await src.exists()) {
        if (await dst.exists()) {
          await dst.delete(recursive: true);
        }
        await _copyDir(src, dst);
      }
    }

    final pj = File(p.join(projectRoot, 'project.json'));
    final map = jsonDecode(await pj.readAsString()) as Map<String, dynamic>;
    final gp = GameProject.fromJson(map);
    final enabled = List<String>.from(gp.lynxPlugins.enabled);
    if (!enabled.contains(pluginId)) enabled.add(pluginId);
    var mode = gp.projectMode;
    if (pluginId == Lynx3dPluginIds.pluginId && mode == LynxProjectMode.d2) {
      mode = LynxProjectMode.d3;
    }
    final next = gp.copyWith(
      lynxPlugins: LynxProjectPlugins(
        apiVersion: gp.lynxPlugins.apiVersion,
        enabled: enabled,
        config: gp.lynxPlugins.config,
      ),
      projectMode: mode,
    );
    await pj.writeAsString(
      const JsonEncoder.withIndent('  ').convert(next.toJson()),
    );
    return LynxMarketplaceInstallResult(
      ok: true,
      message: 'Плагин $pluginId включён в project.json.',
    );
  }

  static Future<String?> _downloadCloudZipToPlugins(
    String projectRoot,
    String pluginId,
    Dio cloudDio,
  ) async {
    try {
      final tmp = File(p.join(projectRoot, '.lynx_dl_$pluginId.zip'));
      await LynxCloudMarketplace(cloudDio).downloadPackage(pluginId, tmp.path);
      final archive = ZipDecoder().decodeBytes(await tmp.readAsBytes());
      final dest = Directory(p.join(projectRoot, 'plugins', pluginId));
      if (dest.existsSync()) await dest.delete(recursive: true);
      dest.createSync(recursive: true);
      for (final f in archive) {
        if (f.isFile) {
          final out = File(p.join(dest.path, f.name));
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(f.content as List<int>);
        }
      }
      await tmp.delete();
      return null;
    } catch (e) {
      return 'Cloud download: $e';
    }
  }

  static Future<String?> _downloadZipToPlugins(
    String projectRoot,
    String url,
    String pluginId,
  ) async {
    try {
      final r = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = r.data;
      if (bytes == null || bytes.isEmpty) return 'Пустой ответ ZIP';
      final archive = ZipDecoder().decodeBytes(bytes);
      final dest = Directory(p.join(projectRoot, 'plugins', pluginId));
      if (dest.existsSync()) await dest.delete(recursive: true);
      dest.createSync(recursive: true);
      for (final f in archive) {
        if (f.isFile) {
          final out = File(p.join(dest.path, f.name));
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(f.content as List<int>);
        }
      }
      return null;
    } catch (e) {
      return 'Ошибка загрузки ZIP: $e';
    }
  }

  static Future<LynxMarketplaceInstallResult> _installAssetPack(
    String projectRoot,
    LynxMarketplaceItem item,
  ) async {
    final url = item.packageUrl;
    if (url == null || url.isEmpty) {
      return const LynxMarketplaceInstallResult(
        ok: false,
        message: 'У пакета нет packageUrl.',
      );
    }
    try {
      final r = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = r.data;
      if (bytes == null) {
        return const LynxMarketplaceInstallResult(ok: false, message: 'Пустой файл');
      }
      final archive = ZipDecoder().decodeBytes(bytes);
      final assetsDir = Directory(p.join(projectRoot, 'assets'));
      assetsDir.createSync(recursive: true);
      for (final f in archive) {
        if (!f.isFile) continue;
        final name = f.name.replaceAll('\\', '/');
        if (name.contains('..')) continue;
        final out = File(p.join(assetsDir.path, name));
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(f.content as List<int>);
      }
      return LynxMarketplaceInstallResult(
        ok: true,
        message: 'Ассеты установлены в assets/',
      );
    } catch (e) {
      return LynxMarketplaceInstallResult(ok: false, message: '$e');
    }
  }

  static Future<void> _copyDir(Directory src, Directory dst) async {
    if (!dst.existsSync()) dst.createSync(recursive: true);
    await for (final entity in src.list(recursive: true)) {
      final rel = p.relative(entity.path, from: src.path);
      final target = p.join(dst.path, rel);
      if (entity is File) {
        await File(target).parent.create(recursive: true);
        await File(entity.path).copy(target);
      } else if (entity is Directory) {
        Directory(target).createSync(recursive: true);
      }
    }
  }

  /// Создание нового проекта из шаблона каталога.
  static Future<LynxMarketplaceInstallResult> createFromTemplateItem({
    required LynxMarketplaceItem item,
    required String destPath,
    required String repoRoot,
    required String displayName,
  }) async {
    final tid = item.templateId ?? item.id;
    final err = await materializeLynxProjectTemplate(
      templateId: tid,
      destPath: destPath,
      repoRoot: repoRoot,
      displayName: displayName,
    );
    if (err != null) {
      return LynxMarketplaceInstallResult(ok: false, message: err);
    }
    return LynxMarketplaceInstallResult(
      ok: true,
      message: 'Проект создан: $destPath',
    );
  }
}
