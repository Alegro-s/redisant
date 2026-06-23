import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../auth/providers/auth_provider.dart';
import '../runtime/engine_binary_loader.dart';
import '../runtime/lynx_cart_io.dart';
import '../runtime/lynx_build_profiles.dart';
import '../runtime/lynx_export.dart';
import '../runtime/lynx_player_build.dart';
import '../../projects/lynx_built_games_registry.dart';

/// Панель сборки игры: EXE (Windows) и APK (Android).
Future<void> showLynxExportSheet(
  BuildContext context, {
  required String projectRoot,
}) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сборка доступна в десктопном Lynx Launcher')),
    );
    return;
  }

  final preset = await showModalBottomSheet<LynxExportPreset>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Сборка игры', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Полная сборка: готовый EXE или APK с вашим проектом.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (Platform.isWindows)
                _ExportTile(
                  icon: Icons.desktop_windows_outlined,
                  title: 'Windows EXE',
                  subtitle: 'flutter build + game_data + ZIP',
                  preset: LynxExportPreset.windows,
                ),
              _ExportTile(
                icon: Icons.android_outlined,
                title: 'Android APK',
                subtitle: 'lynxpack + libengine.so + flutter build apk',
                preset: LynxExportPreset.android,
              ),
              _ExportTile(
                icon: Icons.language_outlined,
                title: 'Web (статика)',
                subtitle: 'game_data для flutter build web',
                preset: LynxExportPreset.web,
              ),
              _ExportTile(
                icon: Icons.inventory_2_outlined,
                title: 'Lynx Cart (.lynxcart)',
                subtitle: 'один файл для Arcade / облака',
                preset: LynxExportPreset.cart,
              ),
              _ExportTile(
                icon: Icons.folder_outlined,
                title: 'Только game_data',
                subtitle: 'папка для ручного Player',
                preset: LynxExportPreset.dataBundle,
              ),
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted || preset == null) return;
  await _runFullBuild(context, projectRoot: projectRoot, preset: preset);
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final LynxExportPreset preset;
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.preset,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context, preset),
    );
  }
}

Future<void> _runFullBuild(
  BuildContext context, {
  required String projectRoot,
  required LynxExportPreset preset,
}) async {
  final auth = Provider.of<AuthProvider>(context, listen: false);

  final parent = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final ctrl = TextEditingController(
        text: p.join(
          p.dirname(projectRoot),
          '${p.basename(projectRoot)}_build',
        ),
      );
      return AlertDialog(
        title: const Text('Папка сборки'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Куда сохранить EXE/APK',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Собрать'),
          ),
        ],
      );
    },
  );
  if (!context.mounted || parent == null || parent.isEmpty) return;

  final progress = _BuildProgressTracker(preset);
  void addLog(String s) => progress.log(s);

  if (!context.mounted) return;
  final buildFuture = _executeBuild(
    projectRoot: projectRoot,
    outputDirectory: parent,
    preset: preset,
    auth: auth,
    onLog: addLog,
  );

  if (!context.mounted) return;
  final err = await showDialog<String?>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _BuildProgressDialog(
      preset: preset,
      progress: progress,
      buildFuture: buildFuture,
    ),
  );

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  if (err != null) {
    messenger.showSnackBar(SnackBar(content: Text(err)));
  } else {
    final projectName = p.basename(projectRoot);
    await LynxBuiltGamesRegistry.recordBuild(
      LynxExportResult(
        preset: preset,
        outputDirectory: parent,
        artifactPaths: [parent],
      ),
      projectPath: projectRoot,
      projectName: projectName,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text('Сборка завершена: $parent'),
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () {
            if (Platform.isWindows) {
              Process.run('explorer', [parent], runInShell: true);
            }
          },
        ),
      ),
    );
  }
}

Future<String?> _executeBuild({
  required String projectRoot,
  required String outputDirectory,
  required LynxExportPreset preset,
  required AuthProvider auth,
  required void Function(String) onLog,
}) async {
  onLog('Подготовка…');
  var lib = await getLastCachedEngineLibraryPath();
  lib ??= await ensureEngineBinary(auth.http);
  if (lib == null &&
      (preset == LynxExportPreset.windows || preset == LynxExportPreset.android)) {
    onLog('Предупреждение: Lynx Engine не найден — Play может не работать.');
  }

  final useFull =
      preset == LynxExportPreset.windows || preset == LynxExportPreset.android;

  if (useFull) {
    return runLynxFullBuild(
      projectRoot: projectRoot,
      outputDirectory: outputDirectory,
      preset: preset,
      engineLibraryAbsolutePath: lib,
      onLog: onLog,
    );
  }

  String? clientRoot;
  if (preset == LynxExportPreset.web) {
    clientRoot = await resolveLynxClientRoot(projectRoot: projectRoot);
  }

  return runLynxExport(
    projectRoot: projectRoot,
    outputDirectory: outputDirectory,
    preset: preset,
    engineLibraryAbsolutePath: lib,
    clientRootForWebStaging: clientRoot,
  );
}

class _BuildProgressTracker extends ChangeNotifier {
  final List<String> logs = [];
  final int totalSteps;
  int step = 0;
  bool done = false;
  String? error;

  _BuildProgressTracker(LynxExportPreset preset)
      : totalSteps = LynxBuildProfile.fromExportPreset(preset).progressSteps;

  void log(String s) {
    logs.add(s);
    if (logs.length > 80) logs.removeAt(0);
    if (!done && step < totalSteps) step++;
    notifyListeners();
  }

  void complete(String? err) {
    error = err;
    done = true;
    step = totalSteps;
    notifyListeners();
  }

  int get percent =>
      totalSteps == 0 ? 0 : ((step / totalSteps) * 100).round().clamp(0, 100);
}

class _BuildProgressDialog extends StatefulWidget {
  final LynxExportPreset preset;
  final _BuildProgressTracker progress;
  final Future<String?> buildFuture;

  const _BuildProgressDialog({
    required this.preset,
    required this.progress,
    required this.buildFuture,
  });

  @override
  State<_BuildProgressDialog> createState() => _BuildProgressDialogState();
}

class _BuildProgressDialogState extends State<_BuildProgressDialog> {
  @override
  void initState() {
    super.initState();
    widget.buildFuture.then((err) {
      widget.progress.complete(err);
      if (!mounted) return;
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.pop(context, err);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.preset) {
      LynxExportPreset.windows => 'Сборка Windows EXE…',
      LynxExportPreset.android => 'Сборка Android APK…',
      _ => 'Экспорт…',
    };
    return ListenableBuilder(
      listenable: widget.progress,
      builder: (context, _) {
        final p = widget.progress;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!p.done) ...[
                  LinearProgressIndicator(value: p.percent / 100),
                  const SizedBox(height: 8),
                  Text(
                    'Шаг ${p.step} из ${p.totalSteps} · ${p.percent}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (p.done && p.error == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Готово'),
                  ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      p.logs.join('\n'),
                      style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
