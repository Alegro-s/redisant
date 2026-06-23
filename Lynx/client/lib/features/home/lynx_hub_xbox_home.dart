import 'package:client/features/engine/runtime/engine_binary_loader.dart';
import 'package:client/features/projects/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'lynx_hub_quick_actions.dart';
import 'widgets/lynx_xbox_tile.dart';

/// Главная зона Hub в стиле Xbox: плоский фон, горизонтальные ряды карточек.
class LynxHubXboxHome extends StatefulWidget {
  const LynxHubXboxHome({super.key});

  @override
  State<LynxHubXboxHome> createState() => _LynxHubXboxHomeState();
}

class _LynxHubXboxHomeState extends State<LynxHubXboxHome> {
  String? _engineLabel;

  @override
  void initState() {
    super.initState();
    _loadEngine();
  }

  Future<void> _loadEngine() async {
    final v = await listInstalledLynxEngineVersions();
    if (!mounted) return;
    setState(() {
      _engineLabel = v.isNotEmpty ? 'Lynx Engine ${v.first}' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final projects = context.watch<ProjectProvider>().projects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: const Color(0xFF252528),
          borderRadius: BorderRadius.circular(24),
          child: TextField(
            readOnly: true,
            onTap: () => context.push('/projects'),
            decoration: InputDecoration(
              hintText: 'Поиск проектов, шаблонов и магазина…',
              hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LynxEngineSetupBanner(compact: true),
        const SizedBox(height: 16),
        LynxXboxSectionHeader(
          title: 'Быстрый старт',
          trailing: TextButton(onPressed: () => context.push('/projects'), child: const Text('Все')),
        ),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 8),
            children: [
              LynxXboxTile(
                title: 'Новый проект',
                subtitle: 'Локально или облако',
                badge: 'NEW',
                accent: cs.primary,
                leading: Icon(Icons.add_circle_outline, size: 48, color: cs.primary),
                onTap: () => context.push('/projects'),
              ),
              const SizedBox(width: 10),
              LynxXboxTile(
                title: 'Tetris Demo',
                subtitle: '480×640 · Lua',
                badge: 'DEMO',
                accent: const Color(0xFF107C10),
                onTap: () => exportTetrisDemoLynxProject(context),
              ),
              const SizedBox(width: 10),
              LynxXboxTile(
                title: 'Platformer',
                subtitle: '2D шаблон',
                accent: const Color(0xFF0078D4),
                onTap: () => context.push('/projects'),
              ),
              const SizedBox(width: 10),
              LynxXboxTile(
                title: 'Lynx Engine',
                subtitle: _engineLabel ?? 'Не установлен',
                accent: _engineLabel != null ? const Color(0xFF107C10) : cs.error,
                leading: Icon(
                  Icons.memory_outlined,
                  size: 44,
                  color: _engineLabel != null ? const Color(0xFF107C10) : cs.error,
                ),
                onTap: () => context.push('/engine-install'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LynxXboxSectionHeader(
          title: 'Мои проекты',
          trailing: TextButton(onPressed: () => context.push('/projects'), child: const Text('Библиотека')),
        ),
        SizedBox(
          height: 200,
          child: projects.isEmpty
              ? Center(
                  child: Text(
                    'Пока нет облачных проектов — создайте в «Проекты»',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 2, right: 8),
                  itemCount: projects.length.clamp(0, 12),
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final p = projects[i];
                    return LynxXboxTile(
                      title: p.name,
                      subtitle: p.visibility == 'public'
                          ? 'Магазин · ${p.shareSlug ?? ''}'
                          : 'Облако',
                      badge: p.visibility == 'public' ? 'STORE' : 'CLOUD',
                      onTap: () => context.push('/project/${p.id}'),
                    );
                  },
                ),
        ),
        const SizedBox(height: 8),
        LynxXboxSectionHeader(title: 'Магазин Lynx'),
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 2, right: 8),
            children: [
              LynxXboxTile(
                title: 'Каталог',
                subtitle: 'Ассеты и шаблоны',
                badge: 'STORE',
                accent: const Color(0xFF9B4F96),
                onTap: () => context.push('/store'),
              ),
              const SizedBox(width: 10),
              LynxXboxTile(
                title: 'Импорт ZIP',
                subtitle: '.lynxproject',
                onTap: () => importProjectZipFromPicker(context),
              ),
              const SizedBox(width: 10),
              LynxXboxTile(
                title: 'Редактор',
                subtitle: 'Открыть Lynx Editor',
                onTap: () => context.push('/engine'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
