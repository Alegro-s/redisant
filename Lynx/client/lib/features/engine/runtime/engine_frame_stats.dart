class EngineFrameStats {
  final double engineUpdateMs;

  final int entityCount;
  final int tilemapLayerCount;

  const EngineFrameStats({
    required this.engineUpdateMs,
    required this.entityCount,
    required this.tilemapLayerCount,
  });
}
