import 'package:client/app/themes/app_theme.dart';
import 'package:client/features/engine/models/models_sprite.dart';
import 'package:flutter/material.dart';


class ProjectStorage extends InheritedWidget {
  final ProjectStorageState data;

  const ProjectStorage({
    Key? key,
    required Widget child,
    required this.data,
  }) : super(key: key, child: child);

  static ProjectStorage? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProjectStorage>();
  }

  static ProjectStorageState of(BuildContext context) {
    final ProjectStorage? result = maybeOf(context);
    assert(result != null, 'No ProjectStorage found in context');
    return result!.data;
  }

  @override
  bool updateShouldNotify(ProjectStorage oldWidget) => true;
}

class ProjectStorageState extends ChangeNotifier {
  final List<PlacedSprite> _sprites = [];
  final List<AssetItem> _assets = [];

  List<PlacedSprite> get sprites => List.unmodifiable(_sprites);
  List<AssetItem> get assets => List.unmodifiable(_assets);

  void addSprite(PlacedSprite sprite, AssetItem asset) {
    _sprites.add(sprite);
    _assets.add(asset);
    notifyListeners();
  }

  void addAsset(AssetItem asset) {
    _assets.add(asset);
    notifyListeners();
  }

  void removeAsset(AssetItem asset) {
    _assets.remove(asset);
    notifyListeners();
  }

  void clearAssets() {
    _assets.clear();
    _sprites.clear();
    notifyListeners();
  }
}

class ProjectStorageProvider extends StatefulWidget {
  final Widget child;

  const ProjectStorageProvider({super.key, required this.child});

  @override
  State<ProjectStorageProvider> createState() => ProjectStorageProviderState();
}

class ProjectStorageProviderState extends State<ProjectStorageProvider> {
  final ProjectStorageState _storageState = ProjectStorageState();

  @override
  Widget build(BuildContext context) {
    return ProjectStorage(
      data: _storageState,
      child: widget.child,
    );
  }
}

class ProjectStorageView extends StatelessWidget {
  const ProjectStorageView({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = ProjectStorage.of(context);
    return AnimatedBuilder(
      animation: storage,
      builder: (context, _) {
        return _buildAssetsGrid(storage);
      },
    );
  }

  Widget _buildAssetsGrid(ProjectStorageState storage) {
    return storage.assets.isEmpty
        ? const Center(
            child: Text(
              'Нет созданных ассетов\nСоздайте спрайты в разделе "Спрайты"',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 15,
              crossAxisSpacing: 10,
              mainAxisSpacing: 15,
              childAspectRatio: 0.50,
            ),
            itemCount: storage.assets.length,
            itemBuilder: (context, index) {
              final asset = storage.assets[index];
              return _AssetItemWidget(asset: asset);
            },
          );
  }
}

class _AssetItemWidget extends StatelessWidget {
  final AssetItem asset;

  const _AssetItemWidget({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: ClassicTheme.BgAssets.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: ClassicTheme.BgAssets.withOpacity(0.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: asset.image != null
                ? Padding(
                    padding: const EdgeInsets.all(1.0),
                    child: RawImage(
                      image: asset.image,
                      fit: BoxFit.contain,
                    ),
                  )
                : Center(
                    child: Icon(
                      _getAssetTypeIcon(asset.assetType),
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              _getDisplayName(asset.name),
              style: const TextStyle(
                color: ClassicTheme.textColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
              decoration: BoxDecoration(
                color: _getAssetTypeColor(asset.assetType).withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: _getAssetTypeColor(asset.assetType).withOpacity(0.5),
                  width: 0.3,
                ),
              ),
              child: Text(
                _getAssetTypeLabel(asset.assetType),
                style: TextStyle(
                  color: _getAssetTypeColor(asset.assetType),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayName(String name) {
    if (name.length <= 18) return name;
    return '${name.substring(0, 6)}...';
  }

  String _getAssetTypeLabel(String type) {
    switch (type) {
      case 'sprite':
        return 'SPR';
      case 'script':
        return 'LUA';
      case 'sound':
        return 'SND';
      default:
        return '???';
    }
  }

  IconData _getAssetTypeIcon(String type) {
    switch (type) {
      case 'sprite':
        return Icons.image;
      case 'script':
        return Icons.code;
      case 'sound':
        return Icons.audiotrack;
      default:
        return Icons.help;
    }
  }

  Color _getAssetTypeColor(String type) {
    switch (type) {
      case 'sprite':
        return ClassicTheme.Type_Sprite;
      case 'script':
        return ClassicTheme.Type_Script;
      case 'sound':
        return ClassicTheme.Type_Sound;
      default:
        return ClassicTheme.Type_None;
    }
  }
}