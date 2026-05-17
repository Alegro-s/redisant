import 'dart:io';
import 'dart:typed_data';

import 'package:client/features/assets/models/asset.dart';
import 'package:client/features/assets/screens/cloud_script_editor_screen.dart';
import 'package:client/features/assets/screens/cloud_sprite_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../providers/asset_provider.dart';
import '../../engine/screens/sprites.dart';

class AssetGrid extends StatefulWidget {
  final String projectId;
  final String assetType;
  final bool readOnly;
  const AssetGrid({super.key, required this.projectId, required this.assetType, this.readOnly = false});

  @override
  State<AssetGrid> createState() => _AssetGridState();
}

class _AssetGridState extends State<AssetGrid> {
  @override
  Widget build(BuildContext context) {
    final assetProvider = Provider.of<AssetProvider>(context);
    final assets = assetProvider.assets.where((a) => a.type == widget.assetType).toList();
    final cs = Theme.of(context).colorScheme;
    final crossAxis = MediaQuery.sizeOf(context).width < 400
        ? 2
        : MediaQuery.sizeOf(context).width < 720
            ? 3
            : 4;

    return Column(
      children: [
        Expanded(
          child: assets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getEmptyIcon(), size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.65)),
                      const SizedBox(height: 12),
                      Text(
                        'Нет ${_getTypeName()}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      if (!widget.readOnly)
                        FilledButton(
                          onPressed: () => _createNewAsset(),
                          child: Text('Создать ${_getTypeNameSingular()}'),
                        ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxis,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: assets.length,
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return Card(
                      child: InkWell(
                        onTap: () => _openAsset(asset),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getAssetIcon(asset.type), size: 30),
                            const SizedBox(height: 4),
                            Text(
                              asset.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (!widget.readOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.icon(
              onPressed: () => _createNewAsset(),
              icon: const Icon(Icons.add_rounded),
              label: Text('Добавить ${_getTypeNameSingular()}'),
            ),
          ),
      ],
    );
  }

  String _getTypeName() {
    switch (widget.assetType) {
      case 'sprite': return 'спрайтов';
      case 'script': return 'скриптов';
      case 'sound': return 'звуков';
      default: return 'ассетов';
    }
  }

  String _getTypeNameSingular() {
    switch (widget.assetType) {
      case 'sprite': return 'спрайт';
      case 'script': return 'скрипт';
      case 'sound': return 'звук';
      default: return 'ассет';
    }
  }

  IconData _getEmptyIcon() {
    switch (widget.assetType) {
      case 'sprite': return Icons.broken_image;
      case 'script': return Icons.code_off;
      case 'sound': return Icons.audiotrack;
      default: return Icons.help;
    }
  }

  IconData _getAssetIcon(String type) {
    switch (type) {
      case 'sprite': return Icons.image;
      case 'script': return Icons.code;
      case 'sound': return Icons.audiotrack;
      default: return Icons.insert_drive_file;
    }
  }

  Future<void> _createNewAsset() async {
    if (widget.readOnly) return;
    if (widget.assetType == 'sprite') {
      final st = this;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (navCtx) => SpriteView(
            projectId: widget.projectId,
            onSave: (String name, Uint8List bytes) async {
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/$name.png');
              await tempFile.writeAsBytes(bytes);
              if (!st.mounted) return;
              final assetProvider = Provider.of<AssetProvider>(st.context, listen: false);
              final error = await assetProvider.uploadAsset(
                widget.projectId,
                tempFile,
                name,
                'sprite',
              );
              await tempFile.delete();
              if (error != null && st.mounted) {
                ScaffoldMessenger.of(st.context).showSnackBar(SnackBar(content: Text(error)));
              }
            },
          ),
        ),
      );
    } else if (widget.assetType == 'script') {
      final ctrl = TextEditingController(
        text: 'script_${DateTime.now().millisecondsSinceEpoch}',
      );
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Новый скрипт'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Имя (без .lua)'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Создать')),
          ],
        ),
      );
      final name = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true || !mounted || name.isEmpty) return;
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final f = File('${tempDir.path}/$name.lua');
      await f.writeAsString('-- NEXUS Lua\nreturn\n');
      if (!mounted) return;
      final assetProvider = Provider.of<AssetProvider>(context, listen: false);
      final error = await assetProvider.uploadAsset(
        widget.projectId,
        f,
        name,
        'script',
      );
      await f.delete();
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      final list = assetProvider.assets;
      final newId = list.isNotEmpty ? list.last.id : null;
      if (newId != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (ctx) => CloudScriptEditorScreen(
              projectId: widget.projectId,
              assetId: newId,
              title: name,
              readOnly: widget.readOnly,
            ),
          ),
        );
      }
    } else if (widget.assetType == 'sound') {
      _pickAudio();
    }
  }

  void _openAsset(Asset asset) {
    if (asset.type == 'sprite') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (ctx) => CloudSpritePreviewScreen(
            assetId: asset.id,
            title: asset.name,
          ),
        ),
      );
    } else if (asset.type == 'script') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (ctx) => CloudScriptEditorScreen(
            projectId: widget.projectId,
            assetId: asset.id,
            title: asset.name,
            readOnly: widget.readOnly,
          ),
        ),
      );
    } else if (asset.type == 'sound') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Прослушивание: ${asset.name}')),
      );
    }
  }

  Future<void> _pickAudio() async {
    final messenger = ScaffoldMessenger.of(context);
    final projectId = widget.projectId;
    final picker = ImagePicker();
    final XFile? file = await picker.pickMedia();
    if (file == null || !mounted) return;
    final assetProvider = Provider.of<AssetProvider>(context, listen: false);
    final error = await assetProvider.uploadAsset(
      projectId,
      File(file.path),
      file.name,
      'sound',
    );
    if (error != null && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }
}