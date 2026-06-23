import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../runtime/tic_grid_codec.dart';

/// Compact TIC map editor — paint sprite tile ids (1–255).
class TicConsoleMapEditor extends StatefulWidget {
  const TicConsoleMapEditor({super.key, required this.projectRoot});

  final String projectRoot;

  @override
  State<TicConsoleMapEditor> createState() => _TicConsoleMapEditorState();
}

class _TicConsoleMapEditorState extends State<TicConsoleMapEditor> {
  late List<int> _cells;
  int _tileId = 1;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _cells = List.filled(TicDimensions.mapW * TicDimensions.mapH, 0);
    _load();
  }

  Future<void> _load() async {
    final f = File(p.join(widget.projectRoot, 'assets', 'tic', 'map.json'));
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
      fileName: 'map.json',
      w: TicDimensions.mapW,
      h: TicDimensions.mapH,
      cells: _cells,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Карта сохранена')),
      );
    }
  }

  void _paintTile(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= TicDimensions.mapW || ty >= TicDimensions.mapH) return;
    setState(() => _cells[ty * TicDimensions.mapW + tx] = _tileId);
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
              const Text('Тайл ID'),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  controller: TextEditingController(text: '$_tileId'),
                  onSubmitted: (v) => setState(() => _tileId = int.tryParse(v)?.clamp(0, 255) ?? 1),
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
              final scale = (c.maxWidth / TicDimensions.mapW).clamp(1.0, 3.0);
              return Center(
                child: GestureDetector(
                  onPanUpdate: (d) => _hit(d.globalPosition, c, scale),
                  onTapDown: (d) => _hit(d.globalPosition, c, scale),
                  child: CustomPaint(
                    size: Size(TicDimensions.mapW * scale, TicDimensions.mapH * scale),
                    painter: _MapPainter(cells: _cells, scale: scale),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _hit(Offset global, BoxConstraints c, double scale) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global);
    final ox = (c.maxWidth - TicDimensions.mapW * scale) / 2;
    final oy = (c.maxHeight - TicDimensions.mapH * scale) / 2;
    final x = ((local.dx - ox) / scale).floor();
    final y = ((local.dy - oy) / scale).floor();
    _paintTile(x, y);
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({required this.cells, required this.scale});
  final List<int> cells;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF1D2B53);
    canvas.drawRect(Offset.zero & size, bg);
    final text = TextPainter(textDirection: TextDirection.ltr);
    for (var ty = 0; ty < TicDimensions.mapH; ty++) {
      for (var tx = 0; tx < TicDimensions.mapW; tx++) {
        final id = cells[ty * TicDimensions.mapW + tx];
        if (id <= 0) continue;
        final hue = (id * 37) % 360;
        final paint = Paint()..color = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.45).toColor();
        canvas.drawRect(Rect.fromLTWH(tx * scale, ty * scale, scale, scale), paint);
        if (scale >= 6) {
          text.text = TextSpan(
            text: '$id',
            style: TextStyle(color: Colors.white, fontSize: scale * 0.35),
          );
          text.layout();
          text.paint(canvas, Offset(tx * scale, ty * scale));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.cells != cells;
}
