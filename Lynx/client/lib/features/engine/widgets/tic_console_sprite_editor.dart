import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../project_manager.dart';
import '../runtime/tic_grid_codec.dart';

/// Compact TIC sprite sheet editor (128×128, 16×16 tiles).
class TicConsoleSpriteEditor extends StatefulWidget {
  const TicConsoleSpriteEditor({super.key, required this.projectRoot});

  final String projectRoot;

  @override
  State<TicConsoleSpriteEditor> createState() => _TicConsoleSpriteEditorState();
}

class _TicConsoleSpriteEditorState extends State<TicConsoleSpriteEditor> {
  late List<int> _cells;
  int _color = 15;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _cells = List.filled(TicDimensions.bankW * TicDimensions.bankH, 0);
    _load();
  }

  Future<void> _load() async {
    final f = File(p.join(widget.projectRoot, 'assets', 'tic', 'sprites.bank.json'));
    if (await f.exists()) {
      try {
        final raw = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final list = (raw['cells'] as List?)?.map((e) => (e as num).toInt()).toList();
        if (list != null && list.length == _cells.length) {
          _cells = list;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await saveTicGridFile(
      projectRoot: widget.projectRoot,
      fileName: 'sprites.bank.json',
      w: TicDimensions.bankW,
      h: TicDimensions.bankH,
      cells: _cells,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Спрайт-банк сохранён')),
      );
    }
  }

  void _paint(int x, int y) {
    if (x < 0 || y < 0 || x >= TicDimensions.bankW || y >= TicDimensions.bankH) return;
    setState(() => _cells[y * TicDimensions.bankW + x] = _color);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Text('Палитра'),
              const SizedBox(width: 8),
              for (var i = 1; i < 16; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = i),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Color(kTicPaletteArgb[i]),
                        border: Border.all(
                          color: _color == i ? Colors.white : Colors.black26,
                          width: _color == i ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Сохранить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final scale = (c.maxWidth / TicDimensions.bankW)
                  .clamp(1.0, 4.0)
                  .floorToDouble()
                  .clamp(1.0, 4.0);
              return Center(
                child: GestureDetector(
                  onPanUpdate: (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(d.globalPosition);
                    final ox = (c.maxWidth - TicDimensions.bankW * scale) / 2;
                    final oy = (c.maxHeight - TicDimensions.bankH * scale) / 2;
                    final x = ((local.dx - ox) / scale).floor();
                    final y = ((local.dy - oy) / scale).floor();
                    _paint(x, y);
                  },
                  onTapDown: (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(d.globalPosition);
                    final ox = (c.maxWidth - TicDimensions.bankW * scale) / 2;
                    final oy = (c.maxHeight - TicDimensions.bankH * scale) / 2;
                    final x = ((local.dx - ox) / scale).floor();
                    final y = ((local.dy - oy) / scale).floor();
                    _paint(x, y);
                  },
                  child: CustomPaint(
                    size: Size(
                      TicDimensions.bankW * scale,
                      TicDimensions.bankH * scale,
                    ),
                    painter: _TicBankPainter(cells: _cells, scale: scale),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TicBankPainter extends CustomPainter {
  _TicBankPainter({required this.cells, required this.scale});
  final List<int> cells;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (var y = 0; y < TicDimensions.bankH; y++) {
      for (var x = 0; x < TicDimensions.bankW; x++) {
        final c = cells[y * TicDimensions.bankW + x];
        if (c <= 0) continue;
        final paint = Paint()..color = Color(kTicPaletteArgb[c.clamp(0, 15)]);
        canvas.drawRect(
          Rect.fromLTWH(x * scale, y * scale, scale, scale),
          paint,
        );
      }
    }
    final grid = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var t = 0; t <= 16; t++) {
      final p = t * TicDimensions.spriteSize * scale;
      canvas.drawLine(Offset(p, 0), Offset(p, size.height), grid);
      canvas.drawLine(Offset(0, p), Offset(size.width, p), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _TicBankPainter old) =>
      old.cells != cells || old.scale != scale;
}

/// Ensures tic asset folder exists when opening console mode.
Future<void> ensureTicProjectAssets(String projectRoot) async {
  final dir = Directory(p.join(projectRoot, 'assets', 'tic'));
  await dir.create(recursive: true);
  final bank = File(p.join(dir.path, 'sprites.bank.json'));
  if (!await bank.exists()) {
    await saveTicGridFile(
      projectRoot: projectRoot,
      fileName: 'sprites.bank.json',
      w: TicDimensions.bankW,
      h: TicDimensions.bankH,
      cells: List.filled(TicDimensions.bankW * TicDimensions.bankH, 0),
    );
  }
  final map = File(p.join(dir.path, 'map.json'));
  if (!await map.exists()) {
    await saveTicGridFile(
      projectRoot: projectRoot,
      fileName: 'map.json',
      w: TicDimensions.mapW,
      h: TicDimensions.mapH,
      cells: List.filled(TicDimensions.mapW * TicDimensions.mapH, 0),
    );
  }
}

/// Register tic assets in project manager if missing.
void registerTicAssetsInManager(ProjectManager manager, String projectRoot) {
  // Assets are file-based under assets/tic; no ProjectAsset row required for Play.
}
