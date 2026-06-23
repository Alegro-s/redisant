import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../engine/runtime/engine_binary_loader.dart';
import '../engine/runtime/lynx_project_templates.dart';
import '../engine/runtime/project_zip_export_io.dart';
import '../engine/runtime/project_zip_import_io.dart';

class LynxHubQuickActions extends StatelessWidget {
  const LynxHubQuickActions({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actions = [
      _HubAction(
        icon: Icons.memory_outlined,
        label: 'Lynx Engine',
        onTap: () => context.push('/engine-install'),
      ),
      _HubAction(
        icon: Icons.create_new_folder_outlined,
        label: 'Проекты',
        onTap: () => context.push('/projects'),
      ),
      _HubAction(
        icon: Icons.upload_file_outlined,
        label: 'Импорт ZIP',
        onTap: () => importProjectZipFromPicker(context),
      ),
      _HubAction(
        icon: Icons.grid_on_outlined,
        label: 'TIC Starter',
        onTap: () => _exportTicStarter(context),
      ),
      _HubAction(
        icon: Icons.grid_on_outlined,
        label: 'Tetris demo',
        onTap: () => exportTetrisDemoLynxProject(context),
      ),
      _HubAction(
        icon: Icons.play_circle_outline,
        label: 'Редактор',
        onTap: () => context.push('/engine'),
      ),
    ];

    if (compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (a) => ActionChip(
                avatar: Icon(a.icon, size: 18, color: cs.primary),
                label: Text(a.label),
                onPressed: a.onTap,
              ),
            )
            .toList(),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _QuickActionTile(action: actions[i], cs: cs),
          ),
        ],
      ],
    );
  }
}

class _HubAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _HubAction({required this.icon, required this.label, required this.onTap});
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.cs});

  final _HubAction action;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cs.surface.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: cs.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LynxEngineSetupBanner extends StatefulWidget {
  const LynxEngineSetupBanner({super.key, this.compact = false});

  final bool compact;

  @override
  State<LynxEngineSetupBanner> createState() => _LynxEngineSetupBannerState();
}

class _LynxEngineSetupBannerState extends State<LynxEngineSetupBanner> {
  bool? _installed;
  String? _label;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final path = await getLastCachedEngineLibraryPath();
    final versions = await listInstalledLynxEngineVersions();
    if (!mounted) return;
    setState(() {
      _installed = path != null || versions.isNotEmpty;
      _label = versions.isNotEmpty ? 'Lynx Engine ${versions.first}' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _installed == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    if (_installed!) {
      if (_label == null) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: widget.compact ? 0 : 10),
        child: Material(
          color: cs.tertiaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            dense: true,
            contentPadding: widget.compact ? const EdgeInsets.symmetric(horizontal: 12) : null,
            leading: Icon(Icons.check_circle_outline, color: cs.tertiary, size: widget.compact ? 20 : 24),
            title: Text(
              widget.compact ? _label! : '$_label готов к Play и предпросмотру',
              style: TextStyle(fontSize: widget.compact ? 13 : 14),
            ),
            trailing: TextButton(
              onPressed: () => context.push('/engine-install'),
              child: const Text('Обновить'),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: widget.compact ? 0 : 10),
      child: Material(
        color: cs.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          contentPadding: widget.compact ? const EdgeInsets.symmetric(horizontal: 12) : null,
          leading: Icon(Icons.warning_amber_rounded, color: cs.error, size: widget.compact ? 20 : 24),
          title: Text(
            'Lynx Engine не установлен',
            style: TextStyle(fontSize: widget.compact ? 13 : 14),
          ),
          subtitle: widget.compact
              ? null
              : const Text(
                  'Импортируйте .lynxengine — без него вкладка «Игра» не запустится.',
                  style: TextStyle(fontSize: 12),
                ),
          trailing: FilledButton.tonal(
            onPressed: () async {
              await context.push('/engine-install');
              await _refresh();
            },
            child: const Text('Установить'),
          ),
        ),
      ),
    );
  }
}

Future<void> _exportTicStarter(BuildContext context) =>
    _exportTemplateProject(context, templateId: 'tic-starter', label: 'TIC Starter');

Future<void> exportTetrisDemoLynxProject(BuildContext context) async =>
    _exportTemplateProject(context, templateId: 'tetris-demo', label: 'Tetris Demo');

Future<void> _exportTemplateProject(
  BuildContext context, {
  required String templateId,
  required String label,
}) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Экспорт .lynxproject доступен в десктопном Lynx Launcher')),
    );
    return;
  }
  final src = resolveTemplateProjectDirectory(templateId);
  if (src == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Шаблон $templateId не найден (переустановите Launcher или откройте из репозитория)',
          ),
        ),
      );
    }
    return;
  }
  final defaultName = suggestedLynxProjectZipFileName(src);
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Сохранить $label',
    fileName: defaultName,
    type: FileType.custom,
    allowedExtensions: const [kLynxProjectZipExtension, 'zip'],
  );
  if (path == null || !context.mounted) return;
  final err = await packProjectDirectoryToZipFile(
    projectRoot: src,
    outputZipPath: path,
  );
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    return;
  }
  var shown = path;
  if (!shown.toLowerCase().endsWith('.zip') &&
      !shown.toLowerCase().endsWith('.$kLynxProjectZipExtension')) {
    shown = '$shown.$kLynxProjectZipExtension';
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Экспорт: ${p.basename(shown)}'),
      action: SnackBarAction(
        label: 'Импорт',
        onPressed: () => importProjectZipFromPicker(context),
      ),
    ),
  );
}

Future<void> importProjectZipFromPicker(BuildContext context) async {
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Импорт ZIP доступен в десктопном Lynx Launcher')),
    );
    return;
  }
  final engine = await getLastCachedEngineLibraryPath();
  if (engine == null && context.mounted) {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Нужен Lynx Engine'),
        content: const Text(
          'Для редактора и Play установите Lynx Engine (.lynxengine), затем повторите импорт.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Установить')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await context.push('/engine-install');
    }
    if (engine == null) return;
  }
  if (!context.mounted) return;
  final pick = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['zip', kLynxProjectZipExtension],
  );
  if (pick == null || pick.files.single.path == null) return;
  final zipPath = pick.files.single.path!;
  final parent = await FilePicker.platform.getDirectoryPath(
    dialogTitle: 'Распаковать проект сюда',
  );
  if (parent == null || !context.mounted) return;
  final baseName = p.basenameWithoutExtension(zipPath);
  var dest = Directory(p.join(parent, baseName));
  if (await dest.exists()) {
    dest = Directory(
      p.join(parent, '${baseName}_${DateTime.now().millisecondsSinceEpoch}'),
    );
  }
  await dest.create(recursive: true);
  final err = await extractZipArchiveToDirectory(
    zipFile: File(zipPath),
    destinationDirectory: dest,
  );
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    return;
  }
  final root = await findNexusProjectRoot(dest.path);
  if (!context.mounted) return;
  if (root == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('В архиве не найден project.json: ${dest.path}')),
    );
    return;
  }
  context.push(
    '/engine',
    extra: {
      'projectPath': root,
      'projectName': p.basename(root),
      'mode': 'offline',
    },
  );
}
