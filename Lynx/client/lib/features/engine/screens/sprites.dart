import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:client/app/themes/app_theme.dart';
import 'package:flutter/material.dart';
import '../models/models_sprite.dart';

enum ToolMode { brush, eraser, pipette }

class SpriteView extends StatefulWidget {
  final String? projectId;
  final String? initialName;
  final String? filePath;
  final Function(String name, Uint8List bytes)? onSave;
  const SpriteView({super.key, this.projectId, this.initialName, this.filePath, this.onSave});
  @override
  State<SpriteView> createState() => _SpriteViewState();
}

class _SpriteViewState extends State<SpriteView> {
  int painterScale = 16;
  final List<int> availableSizes = [8, 16, 32, 64];
  final TextEditingController spriteNameController = TextEditingController();
  late List<List<Color?>> painterPixels;
  SpriteType painterType = SpriteType.Object;
  Color currentColor = Colors.red;
  int brushSize = 1;
  ToolMode _currentTool = ToolMode.brush;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) spriteNameController.text = widget.initialName!;
    _initPainterPixels();
    if (widget.filePath != null) _loadSpriteFromFile();
  }

  void _initPainterPixels() {
    painterPixels = List.generate(painterScale, (_) => List.generate(painterScale, (_) => null));
  }

  Future<void> _loadSpriteFromFile() async {
    final file = File(widget.filePath!);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    final picture = recorder.endRecording();
    final img = await picture.toImage(image.width, image.height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = byteData!.buffer.asUint8List();
    final scale = image.width ~/ painterScale;
    for (int y = 0; y < painterScale; y++) {
      for (int x = 0; x < painterScale; x++) {
        int r = 0, g = 0, b = 0, a = 0, count = 0;
        for (int dy = 0; dy < scale; dy++) {
          for (int dx = 0; dx < scale; dx++) {
            final idx = ((y * scale + dy) * image.width + (x * scale + dx)) * 4;
            r += rgba[idx];
            g += rgba[idx + 1];
            b += rgba[idx + 2];
            a += rgba[idx + 3];
            count++;
          }
        }
        if (count > 0) {
          painterPixels[y][x] = Color.fromARGB(
            (a / count).round(),
            (r / count).round(),
            (g / count).round(),
            (b / count).round(),
          );
        }
      }
    }
    setState(() {});
  }

  Future<ui.Image> _pixelsToImage(List<List<Color?>> pixels) async {
    final int rows = pixels.length;
    final int cols = pixels.isNotEmpty ? pixels[0].length : 0;
    final Uint8List rgba = Uint8List(cols * rows * 4);
    int idx = 0;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final col = pixels[y][x] ?? const Color(0x00000000);
        rgba[idx++] = (col.r * 255).round().clamp(0, 255);
        rgba[idx++] = (col.g * 255).round().clamp(0, 255);
        rgba[idx++] = (col.b * 255).round().clamp(0, 255);
        rgba[idx++] = (col.a * 255).round().clamp(0, 255);
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, cols, rows, ui.PixelFormat.rgba8888, completer.complete);
    return completer.future;
  }

  Future<void> savePainterSprite() async {
    final img = await _pixelsToImage(painterPixels);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    final spriteName = spriteNameController.text.isEmpty ? 'sprite_${DateTime.now().millisecondsSinceEpoch}' : spriteNameController.text;
    if (widget.onSave != null) widget.onSave!(spriteName, pngBytes);
    setState(() { spriteNameController.clear(); _initPainterPixels(); });
  }

  Widget _buildCompactToolButton({
    required IconData icon,
    required String label,
    required ToolMode mode,
    required VoidCallback onTap,
  }) {
    final isSelected = _currentTool == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? ClassicTheme.VideleyeOn : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              Text(label, style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: spriteNameController,
                decoration: const InputDecoration(labelText: 'Sprite name', border: OutlineInputBorder(), isDense: true),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(border: Border.all(color: Colors.white30), borderRadius: BorderRadius.circular(4)),
                  child: SpriteEditorWidget(
                    rows: painterScale,
                    cols: painterScale,
                    pixels: painterPixels,
                    onPaint: (r, c) {
                      setState(() {
                        for (int dy = 0; dy < brushSize; dy++) {
                          for (int dx = 0; dx < brushSize; dx++) {
                            int rr = r + dy, cc = c + dx;
                            if (rr >= 0 && rr < painterScale && cc >= 0 && cc < painterScale) {
                              if (_currentTool == ToolMode.eraser) painterPixels[rr][cc] = null;
                              else if (_currentTool == ToolMode.brush) painterPixels[rr][cc] = currentColor;
                              else if (_currentTool == ToolMode.pipette) {
                                final picked = painterPixels[rr][cc];
                                if (picked != null) { currentColor = picked; _currentTool = ToolMode.brush; }
                              }
                            }
                          }
                        }
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Grid:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(child: Material(color: Colors.transparent, child: DropdownButton<int>(
                  isExpanded: true,
                  value: painterScale,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  items: availableSizes.map((s) => DropdownMenuItem(value: s, child: Text('$s px', style: const TextStyle(fontSize: 11)))).toList(),
                  onChanged: (v) { if (v != null) setState(() { painterScale = v; _initPainterPixels(); }); },
                ))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _buildCompactToolButton(icon: Icons.brush, label: 'Brush', mode: ToolMode.brush, onTap: () => setState(() => _currentTool = ToolMode.brush)),
                _buildCompactToolButton(icon: Icons.cleaning_services, label: 'Eraser', mode: ToolMode.eraser, onTap: () => setState(() => _currentTool = ToolMode.eraser)),
                _buildCompactToolButton(icon: Icons.colorize, label: 'Picker', mode: ToolMode.pipette, onTap: () => setState(() => _currentTool = ToolMode.pipette)),
              ]),
              const SizedBox(height: 8),
              const Text('Palette:', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 4, children: [
                _buildColorSwatch(Colors.red), _buildColorSwatch(Colors.green), _buildColorSwatch(Colors.blue),
                _buildColorSwatch(Colors.yellow), _buildColorSwatch(Colors.orange), _buildColorSwatch(Colors.purple),
                _buildColorSwatch(Colors.white), _buildColorSwatch(Colors.black),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Text('Brush:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(width: 8),
                Expanded(child: Material(color: Colors.transparent, child: DropdownButton<int>(
                  isExpanded: true,
                  value: brushSize,
                  underline: const SizedBox(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  items: const [DropdownMenuItem(value: 1, child: Text('1x1')), DropdownMenuItem(value: 2, child: Text('2x2')), DropdownMenuItem(value: 3, child: Text('3x3'))],
                  onChanged: (v) { if (v != null) setState(() => brushSize = v); },
                ))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ElevatedButton(
                  onPressed: savePainterSprite,
                  style: ElevatedButton.styleFrom(backgroundColor: ClassicTheme.VideleyeOn, padding: const EdgeInsets.symmetric(vertical: 6)),
                  child: const Text('Save', style: TextStyle(fontSize: 11)),
                )),
                const SizedBox(width: 4),
                Expanded(child: ElevatedButton(
                  onPressed: () => setState(() => _initPainterPixels()),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8), padding: const EdgeInsets.symmetric(vertical: 6)),
                  child: const Text('Clear', style: TextStyle(fontSize: 11)),
                )),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorSwatch(Color color) {
    return GestureDetector(
      onTap: () { setState(() { currentColor = color; _currentTool = ToolMode.brush; }); },
      child: Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: currentColor == color ? ClassicTheme.VideleyeOn : Colors.transparent, width: 2),
        ),
      ),
    );
  }
}

class SpriteEditorWidget extends StatefulWidget {
  final int rows; final int cols; final List<List<Color?>> pixels; final void Function(int row, int col) onPaint;
  const SpriteEditorWidget({Key? key, required this.rows, required this.cols, required this.pixels, required this.onPaint}) : super(key: key);
  @override _SpriteEditorWidgetState createState() => _SpriteEditorWidgetState();
}
class _SpriteEditorWidgetState extends State<SpriteEditorWidget> {
  void _handlePaint(Offset local, Offset offset, double cellSize) {
    final dx = local.dx - offset.dx;
    final dy = local.dy - offset.dy;
    if (dx < 0 || dy < 0) return;
    final col = (dx / cellSize).floor();
    final row = (dy / cellSize).floor();
    if (row >= 0 && row < widget.rows && col >= 0 && col < widget.cols) {
      widget.onPaint(row, col);
      setState(() {});
    }
  }
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth, maxH = constraints.maxHeight;
        if (widget.cols <= 0 || widget.rows <= 0) return const SizedBox.shrink();
        final cellSize = (maxW / widget.cols) < (maxH / widget.rows) ? maxW / widget.cols : maxH / widget.rows;
        final gridWidth = cellSize * widget.cols, gridHeight = cellSize * widget.rows;
        final offsetX = (maxW - gridWidth) / 2, offsetY = (maxH - gridHeight) / 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) => _handlePaint(details.localPosition, Offset(offsetX, offsetY), cellSize),
          onPanUpdate: (details) => _handlePaint(details.localPosition, Offset(offsetX, offsetY), cellSize),
          child: CustomPaint(
            size: Size(maxW, maxH),
            painter: SpriteEditorPainter(
              rows: widget.rows, cols: widget.cols, pixels: widget.pixels, offset: Offset(offsetX, offsetY), cellSize: cellSize,
            ),
          ),
        );
      },
    );
  }
}
class SpriteEditorPainter extends CustomPainter {
  final int rows; final int cols; final List<List<Color?>> pixels; final Offset offset; final double cellSize;
  SpriteEditorPainter({required this.rows, required this.cols, required this.pixels, required this.offset, required this.cellSize});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.grey.shade800);
    canvas.save(); canvas.translate(offset.dx, offset.dy);
    for (int r = 0; r < rows; r++) for (int c = 0; c < cols; c++) {
      final color = pixels[r][c];
      if (color != null && color.a != 0) canvas.drawRect(Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize), Paint()..color = color);
    }
    final gridPaint = Paint()..color = Colors.white24..strokeWidth = 1;
    for (int i = 0; i <= cols; i++) canvas.drawLine(Offset(i * cellSize, 0), Offset(i * cellSize, rows * cellSize), gridPaint);
    for (int j = 0; j <= rows; j++) canvas.drawLine(Offset(0, j * cellSize), Offset(cols * cellSize, j * cellSize), gridPaint);
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant SpriteEditorPainter oldDelegate) {
    return oldDelegate.rows != rows || oldDelegate.cols != cols || oldDelegate.cellSize != cellSize || oldDelegate.offset != offset || oldDelegate.pixels != pixels;
  }
}