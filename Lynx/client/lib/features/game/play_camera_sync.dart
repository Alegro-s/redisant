/// Синхронизация камеры Play из JSON движка (исправляет camera 0,0 → центр дизайна).
void applyEngineCameraCenter({
  required Map<String, dynamic> sceneData,
  required double designWidth,
  required double designHeight,
  required void Function(double x, double y) setCenter,
  void Function(double zoom)? setZoom,
}) {
  final cc = sceneData['camera_center'] as Map<String, dynamic>?;
  if (cc != null) {
    var cx = (cc['x'] as num?)?.toDouble() ?? designWidth / 2;
    var cy = (cc['y'] as num?)?.toDouble() ?? designHeight / 2;
    if (cx == 0 && cy == 0) {
      cx = designWidth / 2;
      cy = designHeight / 2;
    }
    setCenter(cx, cy);
  }
  final cams = sceneData['cameras'] as List?;
  if (cams != null && cams.isNotEmpty && setZoom != null) {
    final cam = cams.first as Map<String, dynamic>;
    final z = cam['zoom'];
    if (z is num) setZoom(z.toDouble());
  }
}
