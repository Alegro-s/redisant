class GameRenderSnapshot {
  final List<Map<String, dynamic>> entities;
  final List<Map<String, dynamic>> tilemaps;
  final List<Map<String, dynamic>> rooms;
  final Map<String, Map<String, dynamic>> logicGrids;
  final double cameraX;
  final double cameraY;
  final double zoom;
  final double designWidth;
  final double designHeight;

  const GameRenderSnapshot({
    required this.entities,
    required this.tilemaps,
    required this.rooms,
    this.logicGrids = const {},
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.designWidth,
    required this.designHeight,
  });

  factory GameRenderSnapshot.empty({
    required double designWidth,
    required double designHeight,
    double cameraX = 0,
    double cameraY = 0,
    double zoom = 1,
  }) {
    return GameRenderSnapshot(
      entities: const [],
      tilemaps: const [],
      rooms: const [],
      logicGrids: const {},
      cameraX: cameraX,
      cameraY: cameraY,
      zoom: zoom,
      designWidth: designWidth,
      designHeight: designHeight,
    );
  }

  factory GameRenderSnapshot.fromEngineSceneMap(
    Map<String, dynamic> sceneData, {
    required double cameraX,
    required double cameraY,
    required double zoom,
    required double designWidth,
    required double designHeight,
  }) {
    final rawEnt = sceneData['entities'];
    final entities = rawEnt is List
        ? List<Map<String, dynamic>>.from(
            rawEnt.map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    final rawTiles = sceneData['tilemaps'];
    final tilemaps = rawTiles is List
        ? List<Map<String, dynamic>>.from(
            rawTiles.map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    final rawRooms = sceneData['rooms'];
    final rooms = rawRooms is List
        ? List<Map<String, dynamic>>.from(
            rawRooms.map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : <Map<String, dynamic>>[];

    final rawGrids = sceneData['logic_grids'];
    final logicGrids = <String, Map<String, dynamic>>{};
    if (rawGrids is Map) {
      rawGrids.forEach((key, value) {
        if (value is Map) {
          logicGrids[key.toString()] = Map<String, dynamic>.from(value);
        }
      });
    }

    return GameRenderSnapshot(
      entities: entities,
      tilemaps: tilemaps,
      rooms: rooms,
      logicGrids: logicGrids,
      cameraX: cameraX,
      cameraY: cameraY,
      zoom: zoom,
      designWidth: designWidth,
      designHeight: designHeight,
    );
  }
}
