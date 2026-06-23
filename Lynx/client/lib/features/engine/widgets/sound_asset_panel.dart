import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../models/engine_models.dart';
import '../project_manager.dart';

class SoundAssetPanel extends StatefulWidget {
  const SoundAssetPanel({super.key, required this.assetId});

  final String assetId;

  @override
  State<SoundAssetPanel> createState() => _SoundAssetPanelState();
}

class _SoundAssetPanelState extends State<SoundAssetPanel> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  double _volume = 0.85;
  String? _error;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  ProjectAsset? _asset(ProjectManager mgr) {
    for (final a in mgr.assets) {
      if (a.id == widget.assetId) return a;
    }
    return null;
  }

  Future<void> _play(ProjectManager mgr) async {
    final asset = _asset(mgr);
    final root = mgr.rootPath;
    if (asset == null || root == null) return;
    final file = File(p.join(root, asset.path));
    if (!await file.exists()) {
      setState(() => _error = 'Файл не найден');
      return;
    }
    setState(() {
      _error = null;
      _playing = true;
    });
    try {
      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(DeviceFileSource(file.absolute.path));
    } catch (e) {
      if (mounted) {
        setState(() {
          _playing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _replaceFile(ProjectManager mgr) async {
    if (mgr.isCloudReadOnly || kIsWeb) return;
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3', 'ogg', 'm4a'],
    );
    if (pick == null || pick.files.single.path == null) return;
    final err = await mgr.replaceSoundAssetFile(
      widget.assetId,
      pick.files.single.path!,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Звук заменён')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<ProjectManager>(
      builder: (context, mgr, _) {
        final asset = _asset(mgr);
        if (asset == null) {
          return const Center(child: Text('Ассет не найден'));
        }
        final rel = asset.path.replaceAll('\\', '/');
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq_rounded, color: cs.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          rel,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _playing ? _stop : () => _play(mgr),
                    icon: Icon(_playing ? Icons.stop_rounded : Icons.play_arrow_rounded),
                    label: Text(_playing ? 'Стоп' : 'Прослушать'),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: mgr.isCloudReadOnly ? null : () => _replaceFile(mgr),
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Заменить'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Громкость предпросмотра', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Slider(
                value: _volume,
                onChanged: (v) async {
                  setState(() => _volume = v);
                  await _player.setVolume(v);
                },
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    'play_sound("$rel")',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'В Lua: play_sound("assets/sounds/…") или play_sound_bus("path", "sfx", 0.9)',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.4),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }
}
