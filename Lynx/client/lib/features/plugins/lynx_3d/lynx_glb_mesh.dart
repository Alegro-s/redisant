import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Распарсенный меш из GLB/GLTF (POSITION + индексы, нормали).
class LynxGlbMesh {
  LynxGlbMesh({
    required this.positions,
    required this.indices,
    required this.normals,
  });

  /// xyz interleaved, length = vertexCount * 3.
  final Float32List positions;
  final Uint32List indices;
  final Float32List normals;

  int get vertexCount => positions.length ~/ 3;
  int get triangleCount => indices.length ~/ 3;

  static LynxGlbMesh unitCube() {
    const p = <double>[
      -0.5, -0.5, -0.5, 0.5, -0.5, -0.5, 0.5, 0.5, -0.5, -0.5, 0.5, -0.5,
      -0.5, -0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5,
    ];
    const idx = <int>[
      0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6, 0, 4, 5, 0, 5, 1, 2, 6, 7, 2, 7, 3,
      0, 3, 7, 0, 7, 4, 1, 5, 6, 1, 6, 2,
    ];
    final pos = Float32List.fromList(p);
    return LynxGlbMesh(
      positions: pos,
      indices: Uint32List.fromList(idx),
      normals: _computeNormals(pos, Uint32List.fromList(idx)),
    );
  }

  static Future<LynxGlbMesh?> loadFile(String absolutePath) async {
    if (!File(absolutePath).existsSync()) return null;
    try {
      final bytes = await File(absolutePath).readAsBytes();
      return _parse(bytes);
    } catch (_) {
      return null;
    }
  }

  static LynxGlbMesh? _parse(Uint8List bytes) {
    if (bytes.length < 20) return null;
    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic == 'glTF') {
      return _parseGlb(bytes);
    }
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return _parseGltfJson(map, null);
    } catch (_) {
      return null;
    }
  }

  static LynxGlbMesh? _parseGlb(Uint8List bytes) {
    if (bytes.length < 20) return null;
    final jsonLen = _u32(bytes, 12);
    if (20 + jsonLen > bytes.length) return null;
    final jsonChunk = utf8.decode(bytes.sublist(20, 20 + jsonLen), allowMalformed: true);
    final map = jsonDecode(jsonChunk) as Map<String, dynamic>;
    Uint8List? bin;
    var off = 20 + jsonLen;
    if (off + 8 <= bytes.length) {
      final binLen = _u32(bytes, off);
      off += 8;
      if (off + binLen <= bytes.length) {
        bin = bytes.sublist(off, off + binLen);
      }
    }
    return _parseGltfJson(map, bin);
  }

  static int _u32(Uint8List b, int o) =>
      b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

  static LynxGlbMesh? _parseGltfJson(Map<String, dynamic> root, Uint8List? bin) {
    final meshes = root['meshes'] as List?;
    if (meshes == null || meshes.isEmpty) return null;
    final accessors = root['accessors'] as List? ?? [];
    final views = root['bufferViews'] as List? ?? [];
    final buffers = root['buffers'] as List? ?? [];

    Uint8List bufferBytes( int bufferIndex) {
      if (bin != null && bufferIndex == 0) return bin;
      final b = buffers[bufferIndex] as Map?;
      final uri = b?['uri'] as String?;
      if (uri != null && uri.startsWith('data:')) {
        final comma = uri.indexOf(',');
        if (comma > 0) {
          return base64Decode(uri.substring(comma + 1));
        }
      }
      return Uint8List(0);
    }

    Float32List? readAccessor(int accIdx, {required int components, required int typeSize}) {
      if (accIdx < 0 || accIdx >= accessors.length) return null;
      final acc = accessors[accIdx] as Map;
      final viewIdx = acc['bufferView'] as int?;
      if (viewIdx == null || viewIdx >= views.length) return null;
      final view = views[viewIdx] as Map;
      final bufIdx = view['buffer'] as int? ?? 0;
      final byteOff = (view['byteOffset'] as int? ?? 0) + (acc['byteOffset'] as int? ?? 0);
      final stride = view['byteStride'] as int? ?? (components * typeSize);
      final count = acc['count'] as int? ?? 0;
      final bytes = bufferBytes(bufIdx);
      if (bytes.isEmpty) return null;
      final out = Float32List(count * components);
      var o = byteOff;
      for (var i = 0; i < count; i++) {
        for (var c = 0; c < components; c++) {
          if (o + typeSize > bytes.length) return null;
          out[i * components + c] = _readComponent(bytes, o, typeSize);
          o += typeSize;
        }
        o = byteOff + (i + 1) * stride;
      }
      return out;
    }

    Uint32List? readIndices(int accIdx) {
      if (accIdx < 0 || accIdx >= accessors.length) return null;
      final acc = accessors[accIdx] as Map;
      final viewIdx = acc['bufferView'] as int?;
      if (viewIdx == null) return null;
      final view = views[viewIdx] as Map;
      final bufIdx = view['buffer'] as int? ?? 0;
      final byteOff = (view['byteOffset'] as int? ?? 0) + (acc['byteOffset'] as int? ?? 0);
      final count = acc['count'] as int? ?? 0;
      final compType = acc['componentType'] as int? ?? 5123;
      final bytes = bufferBytes(bufIdx);
      final out = Uint32List(count);
      var o = byteOff;
      for (var i = 0; i < count; i++) {
        if (compType == 5121) {
          out[i] = bytes[o];
          o += 1;
        } else if (compType == 5123) {
          out[i] = bytes[o] | (bytes[o + 1] << 8);
          o += 2;
        } else if (compType == 5125) {
          out[i] = _u32(bytes, o);
          o += 4;
        } else {
          return null;
        }
      }
      return out;
    }

    final mesh0 = meshes[0] as Map;
    final prims = mesh0['primitives'] as List?;
    if (prims == null || prims.isEmpty) return null;
    final prim = prims[0] as Map;
    final attrs = prim['attributes'] as Map?;
    final posIdx = attrs?['POSITION'] as int?;
    if (posIdx == null) return null;
    final pos = readAccessor(posIdx, components: 3, typeSize: 4);
    if (pos == null) return null;
    final normIdx = attrs?['NORMAL'] as int?;
    Float32List normals;
    if (normIdx != null) {
      normals = readAccessor(normIdx, components: 3, typeSize: 4) ??
          _computeNormals(pos, Uint32List(0));
    } else {
      final idxAcc = prim['indices'] as int?;
      final idx = idxAcc != null ? readIndices(idxAcc) : null;
      if (idx != null && idx.isNotEmpty) {
        normals = _computeNormals(pos, idx);
      } else {
        normals = Float32List(pos.length);
        for (var i = 0; i < pos.length; i += 3) {
          normals[i + 1] = 1;
        }
      }
    }
    final idxAcc = prim['indices'] as int?;
    Uint32List indices;
    if (idxAcc != null) {
      indices = readIndices(idxAcc) ?? _sequentialIndices(pos.length ~/ 3);
    } else {
      indices = _sequentialIndices(pos.length ~/ 3);
    }
    if (indices.isEmpty) return null;
    return LynxGlbMesh(positions: pos, indices: indices, normals: normals);
  }

  static double _readComponent(Uint8List b, int o, int size) {
    if (size == 4) {
      return ByteData.sublistView(b, o, o + 4).getFloat32(0, Endian.little);
    }
    return b[o].toDouble();
  }

  static Uint32List _sequentialIndices(int n) {
    final idx = Uint32List(n);
    for (var i = 0; i < n; i++) idx[i] = i;
    return idx;
  }

  static Float32List _computeNormals(Float32List pos, Uint32List idx) {
    final n = Float32List(pos.length);
    void add(int ia, int ib, int ic) {
      final ax = pos[ia], ay = pos[ia + 1], az = pos[ia + 2];
      final bx = pos[ib], by = pos[ib + 1], bz = pos[ib + 2];
      final cx = pos[ic], cy = pos[ic + 1], cz = pos[ic + 2];
      final ux = bx - ax, uy = by - ay, uz = bz - az;
      final vx = cx - ax, vy = cy - ay, vz = cz - az;
      final nx = uy * vz - uz * vy;
      final ny = uz * vx - ux * vz;
      final nz = ux * vy - uy * vx;
      n[ia] += nx;
      n[ia + 1] += ny;
      n[ia + 2] += nz;
      n[ib] += nx;
      n[ib + 1] += ny;
      n[ib + 2] += nz;
      n[ic] += nx;
      n[ic + 1] += ny;
      n[ic + 2] += nz;
    }

    if (idx.isNotEmpty) {
      for (var t = 0; t < idx.length; t += 3) {
        final a = idx[t] * 3, b = idx[t + 1] * 3, c = idx[t + 2] * 3;
        add(a, b, c);
      }
    } else {
      for (var i = 0; i < pos.length; i += 9) {
        add(i, i + 3, i + 6);
      }
    }
    for (var i = 0; i < n.length; i += 3) {
      final len = math.sqrt(n[i] * n[i] + n[i + 1] * n[i + 1] + n[i + 2] * n[i + 2]);
      if (len > 1e-6) {
        n[i] /= len;
        n[i + 1] /= len;
        n[i + 2] /= len;
      } else {
        n[i + 1] = 1;
      }
    }
    return n;
  }
}
