import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// TIC-80 screen / sprite bank dimensions.
class TicDimensions {
  static const displayW = 240;
  static const displayH = 136;
  static const bankW = 128;
  static const bankH = 128;
  static const mapW = 240;
  static const mapH = 136;
  static const spriteSize = 8;
}

/// Official TIC-80 16-color palette (ARGB).
const List<int> kTicPaletteArgb = [
  0xFF000000,
  0xFF1D2B53,
  0xFF7E2553,
  0xFF008751,
  0xFFAB5236,
  0xFF5F574F,
  0xFFC2C3C7,
  0xFFFFF1E8,
  0xFFFF004D,
  0xFFFFA300,
  0xFFFFEC27,
  0xFF00E436,
  0xFF29ADFF,
  0xFF83769C,
  0xFFFF77A8,
  0xFFFFCCAA,
];

Map<String, dynamic> emptyTicGrid(int w, int h) => {
      'w': w,
      'h': h,
      'cells': List.filled(w * h, 0),
    };

/// Load TIC logic grids from `assets/tic/*.json` into scene export map.
Future<Map<String, dynamic>> loadTicLogicGridsForExport(String projectRoot) async {
  final out = <String, dynamic>{
    'display': emptyTicGrid(TicDimensions.displayW, TicDimensions.displayH),
    'tic_bank': emptyTicGrid(TicDimensions.bankW, TicDimensions.bankH),
    'tic_map': emptyTicGrid(TicDimensions.mapW, TicDimensions.mapH),
  };
  final ticDir = Directory(p.join(projectRoot, 'assets', 'tic'));
  if (!await ticDir.exists()) return out;

  Future<void> mergeFile(String name, String gridKey) async {
    final f = File(p.join(ticDir.path, name));
    if (!await f.exists()) return;
    try {
      final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final w = (raw['w'] as num?)?.toInt();
      final h = (raw['h'] as num?)?.toInt();
      final cells = raw['cells'];
      if (w != null && h != null && cells is List) {
        out[gridKey] = {'w': w, 'h': h, 'cells': cells.map((e) => (e as num).toInt()).toList()};
      }
    } catch (_) {}
  }

  await mergeFile('sprites.bank.json', 'tic_bank');
  await mergeFile('map.json', 'tic_map');
  await mergeFile('display.json', 'display');
  return out;
}

Future<void> saveTicGridFile({
  required String projectRoot,
  required String fileName,
  required int w,
  required int h,
  required List<int> cells,
}) async {
  final dir = Directory(p.join(projectRoot, 'assets', 'tic'));
  await dir.create(recursive: true);
  final payload = jsonEncode({'w': w, 'h': h, 'cells': cells});
  await File(p.join(dir.path, fileName)).writeAsString(payload);
}

bool projectUsesTicApi({String? gameTemplate, String? projectMode}) {
  final t = (gameTemplate ?? '').toLowerCase();
  final m = (projectMode ?? '').toLowerCase();
  return t == 'tic' || t == 'cart' || m == 'tic';
}
