import 'dart:convert';
import 'dart:io';
import 'dart:ui';

/// Документ спрайта (слои + кадры) рядом с PNG: `{name}.lynxdoc.json`.
class SpriteDocCodec {
  static String docPathForAsset(String assetRelativePath) {
    final dot = assetRelativePath.lastIndexOf('.');
    if (dot <= 0) return '$assetRelativePath.lynxdoc.json';
    return '${assetRelativePath.substring(0, dot)}.lynxdoc.json';
  }

  static Future<SpriteDocFile?> load(File file) async {
    if (!await file.exists()) return null;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SpriteDocFile.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(File file, SpriteDocFile doc) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(doc.toJson()),
    );
  }
}

class SpriteDocFile {
  SpriteDocFile({
    required this.gridW,
    required this.gridH,
    required this.frames,
    this.frameDelaysMs = const [],
    this.activeFrame = 0,
    this.activeLayer = 0,
    this.version = 1,
  });

  final int version;
  final int gridW;
  final int gridH;
  final List<SpriteDocFrame> frames;
  final List<int> frameDelaysMs;
  final int activeFrame;
  final int activeLayer;

  Map<String, dynamic> toJson() => {
        'version': version,
        'gridW': gridW,
        'gridH': gridH,
        'activeFrame': activeFrame,
        'activeLayer': activeLayer,
        'frameDelaysMs': frameDelaysMs,
        'frames': frames.map((f) => f.toJson()).toList(),
      };

  factory SpriteDocFile.fromJson(Map<String, dynamic> json) {
    final fr = (json['frames'] as List?) ?? const [];
    return SpriteDocFile(
      version: (json['version'] as num?)?.toInt() ?? 1,
      gridW: (json['gridW'] as num?)?.toInt() ?? 32,
      gridH: (json['gridH'] as num?)?.toInt() ?? 32,
      activeFrame: (json['activeFrame'] as num?)?.toInt() ?? 0,
      activeLayer: (json['activeLayer'] as num?)?.toInt() ?? 0,
      frameDelaysMs: (json['frameDelaysMs'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      frames: [
        for (final e in fr)
          SpriteDocFrame.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}

class SpriteDocFrame {
  SpriteDocFrame({required this.layers});

  final List<SpriteDocLayer> layers;

  Map<String, dynamic> toJson() => {
        'layers': layers.map((l) => l.toJson()).toList(),
      };

  factory SpriteDocFrame.fromJson(Map<String, dynamic> json) {
    final ls = (json['layers'] as List?) ?? const [];
    return SpriteDocFrame(
      layers: [
        for (final e in ls)
          SpriteDocLayer.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  }
}

class SpriteDocLayer {
  SpriteDocLayer({
    required this.name,
    required this.visible,
    required this.pixelsArgb,
  });

  final String name;
  final bool visible;
  final List<List<int?>> pixelsArgb;

  Map<String, dynamic> toJson() => {
        'name': name,
        'visible': visible,
        'pixels': pixelsArgb,
      };

  factory SpriteDocLayer.fromJson(Map<String, dynamic> json) {
    final rows = (json['pixels'] as List?) ?? const [];
    return SpriteDocLayer(
      name: json['name'] as String? ?? 'Layer',
      visible: json['visible'] as bool? ?? true,
      pixelsArgb: [
        for (final row in rows)
          [
            for (final c in (row as List))
              c == null ? null : (c as num).toInt(),
          ],
      ],
    );
  }
}

List<List<Color?>> spriteDocPixelsToColors(List<List<int?>> argb) {
  return [
    for (final row in argb)
      [
        for (final c in row)
          c == null ? null : Color(c),
      ],
  ];
}

List<List<int?>> spriteColorsToDocPixels(List<List<Color?>> pixels) {
  return [
    for (final row in pixels)
      [
        for (final c in row) c?.toARGB32(),
      ],
  ];
}
