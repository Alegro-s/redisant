import 'package:client/features/assets/providers/asset_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CloudSpritePreviewScreen extends StatefulWidget {
  final String assetId;
  final String title;

  const CloudSpritePreviewScreen({
    super.key,
    required this.assetId,
    required this.title,
  });

  @override
  State<CloudSpritePreviewScreen> createState() => _CloudSpritePreviewScreenState();
}

class _CloudSpritePreviewScreenState extends State<CloudSpritePreviewScreen> {
  bool _loading = true;
  String? _error;
  MemoryImage? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ap = context.read<AssetProvider>();
    final bytes = await ap.downloadAssetBytes(widget.assetId);
    if (!mounted) return;
    if (bytes == null) {
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить изображение';
      });
      return;
    }
    try {
      setState(() {
        _image = MemoryImage(bytes);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Формат не поддерживается: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : InteractiveViewer(
                  minScale: 0.25,
                  maxScale: 8,
                  child: Center(
                    child: Image(image: _image!),
                  ),
                ),
    );
  }
}
