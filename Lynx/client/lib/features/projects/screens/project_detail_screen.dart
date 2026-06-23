import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../app/providers/settings_provider.dart';
import '../../launcher/lynx_work_launcher.dart';
import '../providers/project_provider.dart';
import '../../assets/providers/asset_provider.dart';
import '../../assets/widgets/asset_grid.dart';
import '../../auth/providers/auth_provider.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool get _runtimeSupportedOnDevice {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssets());
  }

  Future<void> _loadAssets() async {
    final assetProvider = Provider.of<AssetProvider>(context, listen: false);
    final error = await assetProvider.loadAssets(widget.projectId);
    if (error != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _enableShare(ProjectProvider pp) async {
    final err = await pp.enableShare(widget.projectId);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      final p = pp.findById(widget.projectId);
      final slug = p?.shareSlug;
      if (slug != null) {
        await Clipboard.setData(ClipboardData(text: slug));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Slug скопирован: $slug — передайте другу для вступления',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProjectProvider>(
      builder: (context, projectProvider, _) {
        final project = projectProvider.findById(widget.projectId);
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Проект')),
            body: const Center(
              child: Text(
                'Проект не найден. Обновите список в разделе «Проекты».',
              ),
            ),
          );
        }
        final myId = context.read<AuthProvider>().user?.id;
        final readOnly = project.isViewerOnly && project.ownerId != myId;
        Provider.of<AssetProvider>(context);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(project.name),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.image), text: 'Спрайты'),
                  Tab(icon: Icon(Icons.code), text: 'Скрипты'),
                  Tab(icon: Icon(Icons.audiotrack), text: 'Звуки'),
                ],
              ),
              actions: [
                if (!readOnly)
                  IconButton(
                    tooltip: project.shareSlug == null
                        ? 'Включить ссылку-приглашение'
                        : 'Новый slug ссылки',
                    icon: const Icon(Icons.link),
                    onPressed: () => _enableShare(projectProvider),
                  ),
                if (!readOnly && project.shareSlug != null)
                  IconButton(
                    tooltip: 'Копировать slug',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: project.shareSlug!),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Slug скопирован')),
                        );
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Работать',
                  onPressed: () async {
                    await launchLynxWorkOrSnackBar(
                      context,
                      projectId: widget.projectId,
                      projectName: project.name,
                      cloudReadOnly: readOnly,
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                if (readOnly)
                  Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer.withValues(alpha: 0.65),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Режим просмотра: проект по приглашению, загрузка файлов недоступна.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      AssetGrid(
                        projectId: widget.projectId,
                        assetType: 'sprite',
                        readOnly: readOnly,
                      ),
                      AssetGrid(
                        projectId: widget.projectId,
                        assetType: 'script',
                        readOnly: readOnly,
                      ),
                      AssetGrid(
                        projectId: widget.projectId,
                        assetType: 'sound',
                        readOnly: readOnly,
                      ),
                    ],
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
