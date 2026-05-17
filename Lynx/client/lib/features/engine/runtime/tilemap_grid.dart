import '../models/engine_models.dart';

abstract final class TileCollision {
  static const int empty = 0;
  static const int solid = 1;
  static const int oneWay = 2;
  static const int slope45R = 3;
  static const int slope45L = 4;
}

int collisionAtGlobal(TilemapLayerData layer, int gx, int gy) {
  for (final ch in layer.chunks) {
    final gcx = ch.cx * ch.tw;
    final gcy = ch.cy * ch.th;
    final lx = gx - gcx;
    final ly = gy - gcy;
    if (lx < 0 || ly < 0 || lx >= ch.tw || ly >= ch.th) continue;
    final i = ly * ch.tw + lx;
    if (i >= ch.collision.length) return 0;
    return ch.collision[i];
  }
  return 0;
}

int autotileMask16(TilemapLayerData layer, int gx, int gy) {
  int bit(bool v, int shift) => (v ? 1 : 0) << shift;
  final n = collisionAtGlobal(layer, gx, gy - 1) >= 1;
  final e = collisionAtGlobal(layer, gx + 1, gy) >= 1;
  final s = collisionAtGlobal(layer, gx, gy + 1) >= 1;
  final w = collisionAtGlobal(layer, gx - 1, gy) >= 1;
  return (bit(n, 0) | bit(e, 1) | bit(s, 2) | bit(w, 3)) & 0xf;
}

TileChunkData _emptyChunk(int cx, int cy, int tw, int th) {
  final n = tw * th;
  return TileChunkData(
    cx: cx,
    cy: cy,
    tw: tw,
    th: th,
    tileIds: List<int>.filled(n, 0),
    collision: List<int>.filled(n, 0),
  );
}

List<TileChunkData> ensureChunkCell(
  List<TileChunkData> chunks,
  int cx,
  int cy,
  int tw,
  int th,
) {
  for (var i = 0; i < chunks.length; i++) {
    if (chunks[i].cx == cx && chunks[i].cy == cy) {
      return List<TileChunkData>.from(chunks);
    }
  }
  return List<TileChunkData>.from(chunks)..add(_emptyChunk(cx, cy, tw, th));
}

int _divFloor(int a, int b) {
  assert(b > 0);
  if (a >= 0) return a ~/ b;
  return -((-a + b - 1) ~/ b);
}

(int lx, int ly, int cx, int cy) globalToLocal(int gx, int gy, int chunkTw, int chunkTh) {
  final cx = _divFloor(gx, chunkTw);
  final cy = _divFloor(gy, chunkTh);
  final lx = gx - cx * chunkTw;
  final ly = gy - cy * chunkTh;
  return (lx, ly, cx, cy);
}

TilemapLayerData paintWorldCell({
  required TilemapLayerData layer,
  required double worldX,
  required double worldY,
  required int collisionValue,
  required int manualTileId,
  required bool autotile,
  int chunkTw = 32,
  int chunkTh = 32,
}) {
  final ctw = layer.chunks.isNotEmpty ? layer.chunks.first.tw : chunkTw;
  final cth = layer.chunks.isNotEmpty ? layer.chunks.first.th : chunkTh;
  final gx = (worldX / layer.tileW).floor();
  final gy = (worldY / layer.tileH).floor();
  final loc = globalToLocal(gx, gy, ctw, cth);
  var chunks = ensureChunkCell(layer.chunks, loc.$3, loc.$4, ctw, cth);
  final ci = chunks.indexWhere((c) => c.cx == loc.$3 && c.cy == loc.$4);
  final ch = chunks[ci];
  final i = loc.$2 * ch.tw + loc.$1;
  if (i < 0 || i >= ch.tw * ch.th) return layer;

  var newCh = TileChunkData(
    cx: ch.cx,
    cy: ch.cy,
    tw: ch.tw,
    th: ch.th,
    tileIds: List<int>.from(ch.tileIds),
    collision: List<int>.from(ch.collision),
  );
  while (newCh.tileIds.length < ch.tw * ch.th) {
    newCh.tileIds.add(0);
  }
  while (newCh.collision.length < ch.tw * ch.th) {
    newCh.collision.add(0);
  }
  newCh.collision[i] = collisionValue;
  if (!autotile) {
    newCh.tileIds[i] = manualTileId;
  }
  chunks[ci] = newCh;

  var out = TilemapLayerData(
    id: layer.id,
    tileW: layer.tileW,
    tileH: layer.tileH,
    zOrder: layer.zOrder,
    visible: layer.visible,
    tilesetId: layer.tilesetId,
    autotile: layer.autotile,
    chunks: chunks,
  );

  if (autotile) {
    for (final d in const [
      [0, 0],
      [0, -1],
      [1, 0],
      [0, 1],
      [-1, 0],
    ]) {
      out = refreshAutotileAround(out, gx + d[0], gy + d[1], ctw, cth);
    }
  }
  return out;
}

TilemapLayerData refreshAutotileAround(
  TilemapLayerData layer,
  int gx,
  int gy,
  int chunkTw,
  int chunkTh,
) {
  final loc = globalToLocal(gx, gy, chunkTw, chunkTh);
  var chunks = List<TileChunkData>.from(layer.chunks);
  final ci = chunks.indexWhere((c) => c.cx == loc.$3 && c.cy == loc.$4);
  if (ci < 0) return layer;
  final ch = chunks[ci];
  final lx = loc.$1;
  final ly = loc.$2;
  if (lx < 0 || ly < 0 || lx >= ch.tw || ly >= ch.th) return layer;
  final i = ly * ch.tw + lx;
  var newCh = TileChunkData(
    cx: ch.cx,
    cy: ch.cy,
    tw: ch.tw,
    th: ch.th,
    tileIds: List<int>.from(ch.tileIds),
    collision: List<int>.from(ch.collision),
  );
  while (newCh.tileIds.length < ch.tw * ch.th) {
    newCh.tileIds.add(0);
  }
  while (newCh.collision.length < ch.tw * ch.th) {
    newCh.collision.add(0);
  }
  if (newCh.collision[i] >= 1) {
    newCh.tileIds[i] = autotileMask16(layer, gx, gy);
  } else {
    newCh.tileIds[i] = 0;
  }
  chunks[ci] = newCh;
  return TilemapLayerData(
    id: layer.id,
    tileW: layer.tileW,
    tileH: layer.tileH,
    zOrder: layer.zOrder,
    visible: layer.visible,
    tilesetId: layer.tilesetId,
    autotile: layer.autotile,
    chunks: chunks,
  );
}
