import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../arcade/arcade_api_service.dart';
import '../auth/providers/auth_provider.dart';
import '../engine/models/engine_models.dart';
import '../engine/runtime/lynx_cart_io.dart';

/// Публикация `.lynxcart` в Cloud Arcade (L18d).
Future<void> publishProjectCartToArcade(
  BuildContext context, {
  required String projectRoot,
  GameProject? project,
}) async {
  final auth = context.read<AuthProvider>();
  final api = ArcadeApiService(auth.http);
  final pjFile = File('$projectRoot/project.json');
  if (!await pjFile.exists()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('project.json не найден')),
    );
    return;
  }
  final pj = project ??
      GameProject.fromJson(
        jsonDecode(await pjFile.readAsString()) as Map<String, dynamic>,
      );
  final cloud = pj.cloudPublish;
  if (cloud == null || !cloud.enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Включите cloudPublish в настройках проекта')),
    );
    return;
  }
  final dist = Directory('$projectRoot/dist');
  await dist.create(recursive: true);
  final out = '${dist.path}/${pj.displayName.replaceAll(RegExp(r'[^\w\-]+'), '_')}$kLynxCartExtension';
  final file = await packProjectToLynxCart(
    projectRoot: projectRoot,
    outputPath: out,
    manifest: LynxCartManifest(
      title: cloud.title.isNotEmpty ? cloud.title : pj.displayName,
      tier: cloud.tier,
      tags: cloud.tags,
      cartId: pj.projectId,
      designWidth: pj.designWidth,
      designHeight: pj.designHeight,
    ),
  );
  final result = await api.uploadCart(
    cartFilePath: file.path,
    manifest: LynxCartManifest(
      title: cloud.title.isNotEmpty ? cloud.title : pj.displayName,
      tier: cloud.tier,
      tags: cloud.tags,
      cartId: pj.projectId,
    ),
    cartId: pj.projectId,
  );
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.ok ? result.message : 'Ошибка публикации: ${result.message}'),
    ),
  );
}
