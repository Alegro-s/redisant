/// Параметры тайлсета из `project.json` для отрисовки атласа.
class TilesetCatalogEntry {
  TilesetCatalogEntry({
    required this.id,
    this.texturePath = '',
    this.columns = 16,
    this.sourceTileW = 32,
    this.sourceTileH = 32,
  });

  final String id;
  final String texturePath;
  final int columns;
  final double sourceTileW;
  final double sourceTileH;

  factory TilesetCatalogEntry.fromJson(Map<String, dynamic> json) {
    final tw = (json['tileWidth'] as num?)?.toDouble() ??
        (json['tile_width'] as num?)?.toDouble() ??
        32.0;
    final th = (json['tileHeight'] as num?)?.toDouble() ??
        (json['tile_height'] as num?)?.toDouble() ??
        tw;
    return TilesetCatalogEntry(
      id: json['id'] as String? ?? '',
      texturePath: (json['texturePath'] as String? ?? json['texture_path'] as String? ?? '')
          .replaceAll('\\', '/'),
      columns: (json['columns'] as num?)?.toInt() ?? 16,
      sourceTileW: tw,
      sourceTileH: th,
    );
  }

  static TilesetCatalogEntry? find(List<Map<String, dynamic>> catalog, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final raw in catalog) {
      final e = TilesetCatalogEntry.fromJson(Map<String, dynamic>.from(raw));
      if (e.id == id) return e;
    }
    return null;
  }
}
