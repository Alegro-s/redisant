import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../project_manager.dart';
import '../runtime/sprite_doc_codec.dart';
import 'sprite_palette_presets.dart';

enum _PixelTool { pencil, eraser, fill, eyedropper }

class _SpriteLayer {
  _SpriteLayer({required this.name, required this.pixels, this.visible = true});
  String name;
  List<List<Color?>> pixels;
  bool visible;
}

class _DocSnapshot {
  _DocSnapshot(this.frames, this.frameIndex, this.activeLayerIndex);
  final List<List<_SpriteLayer>> frames;
  final int frameIndex;
  final int activeLayerIndex;
}

class SpriteEditor extends StatefulWidget {
  final String assetId;
  const SpriteEditor({super.key, required this.assetId});

  @override
  State<SpriteEditor> createState() => _SpriteEditorState();
}

class _SpriteEditorState extends State<SpriteEditor> {
  static const int _maxSide = 256;
  static const List<int> _presets = [8, 16, 24, 32, 48, 64, 96, 128];

  int _gridW = 32;
  int _gridH = 32;
  List<List<_SpriteLayer>> _frames = [];
  int _frameIndex = 0;
  int _activeLayerIndex = 0;
  bool _onionSkin = false;
  Timer? _animTimer;
  int _animDelayMs = 150;
  bool _animPlaying = false;
  _PixelTool _tool = _PixelTool.pencil;
  Color _currentColor = const Color(0xFFe53935);
  SpritePalettePreset _palettePreset = SpritePalettePreset.basic;
  int _brush = 1;
  bool _loading = true;
  bool _dirty = false;
  bool _checkerTransparency = true;
  bool _undoPushedForStroke = false;
  final List<_DocSnapshot> _undoStack = [];
  final List<_DocSnapshot> _redoStack = [];
  ProjectManager? _mgr;
  int _lastAppliedStudioRev = 0;

  List<_SpriteLayer> get _currentFrameLayers {
    if (_frames.isEmpty) return [];
    final i = _frameIndex.clamp(0, _frames.length - 1);
    return _frames[i];
  }

  List<List<Color?>> get _activePixels {
    final ls = _currentFrameLayers;
    if (ls.isEmpty) {
      return List.generate(_gridH, (_) => List<Color?>.filled(_gridW, null));
    }
    final li = _activeLayerIndex.clamp(0, ls.length - 1);
    return ls[li].pixels;
  }

  List<List<Color?>> _compositeFrame(int fi) {
    if (_frames.isEmpty || fi < 0 || fi >= _frames.length) {
      return List.generate(_gridH, (_) => List<Color?>.filled(_gridW, null));
    }
    final layers = _frames[fi];
    final out = List.generate(_gridH, (y) => List<Color?>.generate(_gridW, (x) => null));
    for (final layer in layers) {
      if (!layer.visible) continue;
      for (int y = 0; y < _gridH; y++) {
        for (int x = 0; x < _gridW; x++) {
          final c = layer.pixels[y][x];
          if (c != null) out[y][x] = c;
        }
      }
    }
    return out;
  }

  List<List<_SpriteLayer>> _cloneAllFrames() {
    return [
      for (final fr in _frames)
        [
          for (final L in fr)
            _SpriteLayer(
              name: L.name,
              visible: L.visible,
              pixels: [for (final r in L.pixels) List<Color?>.from(r)],
            ),
        ],
    ];
  }

  void _restoreSnapshot(_DocSnapshot snap) {
    _frames = [
      for (final fr in snap.frames)
        [
          for (final L in fr)
            _SpriteLayer(
              name: L.name,
              visible: L.visible,
              pixels: [for (final r in L.pixels) List<Color?>.from(r)],
            ),
        ],
    ];
    _frameIndex = snap.frameIndex.clamp(0, _frames.isEmpty ? 0 : _frames.length - 1);
    final ls = _currentFrameLayers;
    _activeLayerIndex = ls.isEmpty ? 0 : snap.activeLayerIndex.clamp(0, ls.length - 1);
    if (ls.isNotEmpty) {
      _gridW = ls.first.pixels.first.length;
      _gridH = ls.first.pixels.length;
    }
  }

  void _pushUndo() {
    _undoStack.add(_DocSnapshot(_cloneAllFrames(), _frameIndex, _activeLayerIndex));
    if (_undoStack.length > 48) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_DocSnapshot(_cloneAllFrames(), _frameIndex, _activeLayerIndex));
    final prev = _undoStack.removeLast();
    setState(() {
      _restoreSnapshot(prev);
      _dirty = true;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_DocSnapshot(_cloneAllFrames(), _frameIndex, _activeLayerIndex));
    final next = _redoStack.removeLast();
    setState(() {
      _restoreSnapshot(next);
      _dirty = true;
    });
  }

  void _stopAnim() {
    _animTimer?.cancel();
    _animTimer = null;
    _animPlaying = false;
  }

  void _toggleAnimPlay() {
    if (_frames.length < 2) return;
    if (_animPlaying) {
      _stopAnim();
      setState(() {});
      return;
    }
    setState(() => _animPlaying = true);
    _animTimer?.cancel();
    _animTimer = Timer.periodic(Duration(milliseconds: _animDelayMs.clamp(40, 2000)), (_) {
      if (!mounted) return;
      setState(() {
        _frameIndex = (_frameIndex + 1) % _frames.length;
      });
    });
  }

  List<_SpriteLayer> _cloneFrameLayers(int fi) {
    return [
      for (final L in _frames[fi])
        _SpriteLayer(
          name: L.name,
          visible: L.visible,
          pixels: [for (final r in L.pixels) List<Color?>.from(r)],
        ),
    ];
  }

  void _addLayer() {
    if (_frames.isEmpty) return;
    _pushUndo();
    final blank = List.generate(_gridH, (_) => List<Color?>.filled(_gridW, null));
    setState(() {
      _frames[_frameIndex].add(
        _SpriteLayer(name: 'Слой ${_frames[_frameIndex].length + 1}', pixels: blank),
      );
      _activeLayerIndex = _frames[_frameIndex].length - 1;
      _dirty = true;
    });
  }

  void _removeActiveLayer() {
    final ls = _currentFrameLayers;
    if (ls.length <= 1) return;
    _pushUndo();
    setState(() {
      _frames[_frameIndex].removeAt(_activeLayerIndex);
      if (_activeLayerIndex >= _frames[_frameIndex].length) {
        _activeLayerIndex = _frames[_frameIndex].length - 1;
      }
      _dirty = true;
    });
  }

  void _mergeDown() {
    if (_activeLayerIndex <= 0) return;
    _pushUndo();
    setState(() {
      final ls = _frames[_frameIndex];
      final below = ls[_activeLayerIndex - 1].pixels;
      final above = ls[_activeLayerIndex].pixels;
      for (int y = 0; y < _gridH; y++) {
        for (int x = 0; x < _gridW; x++) {
          final c = above[y][x];
          if (c != null) below[y][x] = c;
        }
      }
      ls.removeAt(_activeLayerIndex);
      _activeLayerIndex--;
      _dirty = true;
    });
  }

  void _duplicateAnimFrame() {
    if (_frames.isEmpty) return;
    _pushUndo();
    setState(() {
      _frames.insert(_frameIndex + 1, _cloneFrameLayers(_frameIndex));
      _frameIndex++;
      _dirty = true;
    });
  }

  void _removeAnimFrame() {
    if (_frames.length <= 1) return;
    _pushUndo();
    _stopAnim();
    setState(() {
      _frames.removeAt(_frameIndex);
      if (_frameIndex >= _frames.length) _frameIndex = _frames.length - 1;
      _activeLayerIndex = _activeLayerIndex.clamp(0, _currentFrameLayers.length - 1);
      _dirty = true;
    });
  }

  void _mirrorHorizontal() {
    _pushUndo();
    final px = _activePixels;
    setState(() {
      for (var y = 0; y < _gridH; y++) {
        for (var x = 0; x < _gridW ~/ 2; x++) {
          final t = px[y][x];
          final ox = _gridW - 1 - x;
          px[y][x] = px[y][ox];
          px[y][ox] = t;
        }
      }
      _dirty = true;
    });
  }

  Future<void> _dialogPickColor() async {
    final ctrl = TextEditingController(
      text: _currentColor.toARGB32().toRadixString(16).padLeft(8, '0'),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Цвет (ARGB hex)'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'ffe53935',
            labelText: '8 hex-символов',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true && mounted) {
      var s = ctrl.text.trim();
      if (s.startsWith('#')) s = s.substring(1);
      final v = int.tryParse(s, radix: 16);
      if (v != null) {
        setState(() => _currentColor = Color(v));
      }
    }
    ctrl.dispose();
  }

  void _initDoc(int w, int h) {
    _gridW = w;
    _gridH = h;
    final blank = List.generate(h, (_) => List<Color?>.filled(w, null));
    _frames = [
      [_SpriteLayer(name: 'Слой 1', pixels: [for (final r in blank) List<Color?>.from(r)])],
    ];
    _frameIndex = 0;
    _activeLayerIndex = 0;
  }

  @override
  void initState() {
    super.initState();
    _initDoc(_gridW, _gridH);
    _mgr = context.read<ProjectManager>();
    _mgr!.addListener(_onProjectManagerNotify);
    _loadSprite();
  }

  void _onProjectManagerNotify() {
    if (!mounted || _mgr == null) return;
    unawaited(_applyRemoteIfNeeded(_mgr!));
  }

  Future<void> _applyRemoteIfNeeded(ProjectManager manager) async {
    if (_loading) return;
    final cid = manager.cloudAssetIdForProjectAssetId(widget.assetId);
    if (cid == null) return;
    final rev = manager.studioAssetRefreshRevision(cid);
    if (rev == _lastAppliedStudioRev || _dirty) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _reloadPixelsFromDisk(manager);
      _lastAppliedStudioRev = rev;
      _dirty = false;
      _undoStack.clear();
      _redoStack.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Спрайт обновлён из облака')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadPixelsFromDisk(ProjectManager manager) async {
    final asset = manager.assets.firstWhere((a) => a.id == widget.assetId);
    final docPath = SpriteDocCodec.docPathForAsset(asset.path);
    final docRaw = await manager.readAssetText(docPath);
    if (docRaw != null) {
      try {
        final doc = SpriteDocFile.fromJson(
          jsonDecode(docRaw) as Map<String, dynamic>,
        );
        if (doc.frames.isNotEmpty) {
          setState(() {
            _gridW = doc.gridW;
            _gridH = doc.gridH;
            _frames = [
              for (final fr in doc.frames)
                [
                  for (final layer in fr.layers)
                    _SpriteLayer(
                      name: layer.name,
                      visible: layer.visible,
                      pixels: spriteDocPixelsToColors(layer.pixelsArgb),
                    ),
                ],
            ];
            _frameIndex = doc.activeFrame.clamp(0, _frames.length - 1);
            _activeLayerIndex = doc.activeLayer.clamp(
              0,
              _currentFrameLayers.isEmpty ? 0 : _currentFrameLayers.length - 1,
            );
            if (doc.frameDelaysMs.isNotEmpty) {
              _animDelayMs =
                  doc.frameDelaysMs[_frameIndex.clamp(0, doc.frameDelaysMs.length - 1)];
            }
          });
          return;
        }
      } catch (_) {}
    }
    final bytes = await manager.readAssetBytes(asset.path);
    if (bytes == null) return;
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    var img = frame.image;
    final iw = img.width;
    final ih = img.height;
    if (iw > _maxSide || ih > _maxSide) {
      final s = math.min(_maxSide / iw, _maxSide / ih);
      final tw = math.max(1, (iw * s).round());
      final th = math.max(1, (ih * s).round());
      img = await _scaleImage(img, tw, th);
    }
    if (mounted) {
      await _imageToPixels(img);
    } else {
      img.dispose();
    }
  }

  Future<ui.Image> _scaleImage(ui.Image src, int tw, int th) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      src,
      Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
      Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
      Paint()..filterQuality = FilterQuality.none,
    );
    final pic = recorder.endRecording();
    final out = await pic.toImage(tw, th);
    src.dispose();
    return out;
  }

  Future<void> _imageToPixels(ui.Image img) async {
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    if (bd == null) {
      img.dispose();
      return;
    }
    final w = img.width;
    final h = img.height;
    final rows = List.generate(h, (y) => List<Color?>.filled(w, null));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final r = bd.getUint8(i);
        final g = bd.getUint8(i + 1);
        final b = bd.getUint8(i + 2);
        final a = bd.getUint8(i + 3);
        rows[y][x] = a < 8 ? null : Color.fromARGB(a, r, g, b);
      }
    }
    setState(() {
      _gridW = w;
      _gridH = h;
      _frames = [[_SpriteLayer(name: 'Слой 1', pixels: rows)]];
      _frameIndex = 0;
      _activeLayerIndex = 0;
    });
    img.dispose();
  }

  Future<void> _loadSprite() async {
    final manager = _mgr ?? Provider.of<ProjectManager>(context, listen: false);
    await _reloadPixelsFromDisk(manager);
    final cid = manager.cloudAssetIdForProjectAssetId(widget.assetId);
    _lastAppliedStudioRev = manager.studioAssetRefreshRevision(cid);
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _stopAnim();
    _mgr?.removeListener(_onProjectManagerNotify);
    super.dispose();
  }

  Future<Uint8List?> _encodeCompositePng(List<List<Color?>> comp) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (int y = 0; y < _gridH; y++) {
      for (int x = 0; x < _gridW; x++) {
        final c = comp[y][x];
        if (c != null) {
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1),
            Paint()..color = c,
          );
        }
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(_gridW, _gridH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveSprite() async {
    final manager = Provider.of<ProjectManager>(context, listen: false);
    if (manager.rootPath == null) return;
    final comp = _compositeFrame(_frameIndex);
    final pngBytes = await _encodeCompositePng(comp);
    if (pngBytes == null) return;
    final asset = manager.assets.firstWhere((a) => a.id == widget.assetId);
    final f = File('${manager.rootPath}/${asset.path}');
    await f.writeAsBytes(pngBytes);
    final doc = SpriteDocFile(
      gridW: _gridW,
      gridH: _gridH,
      activeFrame: _frameIndex,
      activeLayer: _activeLayerIndex,
      frameDelaysMs: List.generate(
        _frames.length,
        (i) => _animDelayMs,
      ),
      frames: [
        for (final fr in _frames)
          SpriteDocFrame(
            layers: [
              for (final layer in fr)
                SpriteDocLayer(
                  name: layer.name,
                  visible: layer.visible,
                  pixelsArgb: spriteColorsToDocPixels(layer.pixels),
                ),
            ],
          ),
      ],
    );
    await SpriteDocCodec.save(
      File('${manager.rootPath}/${SpriteDocCodec.docPathForAsset(asset.path)}'),
      doc,
    );
    await manager.reloadSpriteAsset(widget.assetId);
    setState(() => _dirty = false);
    var cloudOk = false;
    if (manager.canPushCloudAsset) {
      cloudOk = await manager.syncLocalAssetBytesToCloud(widget.assetId, pngBytes);
      _lastAppliedStudioRev =
          manager.studioAssetRefreshRevision(manager.cloudAssetIdForProjectAssetId(widget.assetId));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cloudOk
                ? 'Спрайт сохранён и отправлен в облако'
                : (manager.canPushCloudAsset
                    ? 'Спрайт сохранён локально; не удалось синхронизировать с облаком'
                    : 'Спрайт сохранён в assets'),
          ),
        ),
      );
    }
  }

  Future<void> _exportPngCopy() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Экспорт в файл в веб-клиенте ограничен — используйте «Сохранить»')),
      );
      return;
    }
    final manager = Provider.of<ProjectManager>(context, listen: false);
    if (manager.rootPath == null) return;
    final asset = manager.assets.firstWhere((a) => a.id == widget.assetId);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Экспорт PNG',
      fileName: '${asset.name}.png',
      type: FileType.custom,
      allowedExtensions: const ['png'],
    );
    if (path == null || !mounted) return;
    final comp = _compositeFrame(_frameIndex);
    final pngBytes = await _encodeCompositePng(comp);
    if (pngBytes == null) return;
    var outPath = path;
    if (!outPath.toLowerCase().endsWith('.png')) outPath = '$outPath.png';
    await File(outPath).writeAsBytes(pngBytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Экспорт: $outPath')));
    }
  }

  void _applyTool(int cx, int cy) {
    if (cx < 0 || cy < 0 || cx >= _gridW || cy >= _gridH) return;
    if (_tool == _PixelTool.eyedropper) {
      final comp = _compositeFrame(_frameIndex);
      final c = comp[cy][cx];
      if (c != null) {
        setState(() => _currentColor = c);
      }
      return;
    }
    final px = _activePixels;
    setState(() {
      _dirty = true;
      if (_tool == _PixelTool.fill) {
        _floodFill(px, cx, cy, px[cy][cx], _currentColor);
        return;
      }
      for (int dy = 0; dy < _brush; dy++) {
        for (int dx = 0; dx < _brush; dx++) {
          final nx = cx + dx;
          final ny = cy + dy;
          if (nx < _gridW && ny < _gridH) {
            px[ny][nx] = _tool == _PixelTool.eraser ? null : _currentColor;
          }
        }
      }
    });
  }

  void _floodFill(List<List<Color?>> pixels, int x, int y, Color? target, Color replacement) {
    if (target == replacement) return;
    final stack = <Offset>[Offset(x.toDouble(), y.toDouble())];
    final seen = <int>{};
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      final ix = p.dx.toInt();
      final iy = p.dy.toInt();
      final key = iy * _gridW + ix;
      if (ix < 0 || iy < 0 || ix >= _gridW || iy >= _gridH) continue;
      if (seen.contains(key)) continue;
      if (pixels[iy][ix] != target) continue;
      seen.add(key);
      pixels[iy][ix] = replacement;
      stack.add(Offset(ix + 1.0, iy.toDouble()));
      stack.add(Offset(ix - 1.0, iy.toDouble()));
      stack.add(Offset(ix.toDouble(), iy + 1.0));
      stack.add(Offset(ix.toDouble(), iy - 1.0));
    }
  }

  void _strokeAtLocal(Offset local, double side) {
    final cellW = side / _gridW;
    final cellH = side / _gridH;
    final cx = (local.dx / cellW).floor().clamp(0, _gridW - 1);
    final cy = (local.dy / cellH).floor().clamp(0, _gridH - 1);
    _applyTool(cx, cy);
  }

  void _newSize(int w, int h) {
    if (w == _gridW && h == _gridH) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый размер'),
        content: Text('Холст станет $w×$h (текущее будет сброшено).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pushUndo();
              _stopAnim();
              setState(() {
                _initDoc(w, h);
                _dirty = true;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final palette = colorsForSpritePalettePreset(_palettePreset);
    final managerWatch = context.watch<ProjectManager>();
    final cid = managerWatch.cloudAssetIdForProjectAssetId(widget.assetId);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final mod = HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;
        if (mod && event.logicalKey == LogicalKeyboardKey.keyZ) {
          _undo();
          return KeyEventResult.handled;
        }
        if (mod && event.logicalKey == LogicalKeyboardKey.keyY) {
          _redo();
          return KeyEventResult.handled;
        }
        if (mod && event.logicalKey == LogicalKeyboardKey.keyS) {
          if (_dirty) _saveSprite();
          return KeyEventResult.handled;
        }
        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyB:
            setState(() => _tool = _PixelTool.pencil);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyE:
            setState(() => _tool = _PixelTool.eraser);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyG:
            setState(() => _tool = _PixelTool.fill);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyI:
            setState(() => _tool = _PixelTool.eyedropper);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.keyP:
            _toggleAnimPlay();
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cid != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
            child: Text(
              'Облако: live-обновление PNG (без несохранённых правок на холсте)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              SegmentedButton<_PixelTool>(
                segments: const [
                  ButtonSegment(value: _PixelTool.pencil, label: Text('Карандаш'), icon: Icon(Icons.edit, size: 16)),
                  ButtonSegment(value: _PixelTool.eraser, label: Text('Ластик'), icon: Icon(Icons.auto_fix_off, size: 16)),
                  ButtonSegment(value: _PixelTool.fill, label: Text('Заливка'), icon: Icon(Icons.format_color_fill, size: 16)),
                  ButtonSegment(value: _PixelTool.eyedropper, label: Text('Пипетка'), icon: Icon(Icons.colorize, size: 16)),
                ],
                selected: {_tool},
                onSelectionChanged: (s) => setState(() => _tool = s.first),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _brush.clamp(1, 4),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Кисть 1')),
                  DropdownMenuItem(value: 2, child: Text('Кисть 2')),
                  DropdownMenuItem(value: 3, child: Text('Кисть 3')),
                  DropdownMenuItem(value: 4, child: Text('Кисть 4')),
                ],
                onChanged: (v) => setState(() => _brush = v ?? 1),
              ),
              const SizedBox(width: 8),
              DropdownButton<SpritePalettePreset>(
                value: _palettePreset,
                underline: const SizedBox.shrink(),
                items: SpritePalettePreset.values
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(labelForSpritePalettePreset(p)),
                      ),
                    )
                    .toList(),
                onChanged: (p) {
                  if (p != null) setState(() => _palettePreset = p);
                },
              ),
              const SizedBox(width: 8),
              ...palette.map(
                (c) => Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: InkWell(
                    onTap: () => setState(() => _currentColor = c),
                    child: CircleAvatar(
                      radius: _palettePreset == SpritePalettePreset.db32 ? 10 : 14,
                      backgroundColor: c,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Холст:', style: TextStyle(fontSize: 12)),
                  ..._presets.map(
                    (s) => ActionChip(
                      label: Text('$s²'),
                      onPressed: () => _newSize(s, s),
                    ),
                  ),
                  Text('$_gridW×$_gridH', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  FilterChip(
                    label: const Text('Шахматы'),
                    selected: _checkerTransparency,
                    onSelected: (v) => setState(() => _checkerTransparency = v),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('Кадры', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    const SizedBox(width: 6),
                    for (var i = 0; i < _frames.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Text('$i', style: const TextStyle(fontSize: 11)),
                          selected: _frameIndex == i,
                          onSelected: (_) {
                            _stopAnim();
                            setState(() {
                              _frameIndex = i;
                              _activeLayerIndex =
                                  _activeLayerIndex.clamp(0, _currentFrameLayers.length - 1);
                            });
                          },
                        ),
                      ),
                    IconButton(
                      tooltip: 'Дублировать кадр',
                      icon: const Icon(Icons.add_box_outlined, size: 20),
                      onPressed: _duplicateAnimFrame,
                    ),
                    IconButton(
                      tooltip: 'Удалить кадр',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: _frames.length > 1 ? _removeAnimFrame : null,
                    ),
                    IconButton(
                      tooltip: _animPlaying ? 'Пауза' : 'Проигрывание',
                      icon: Icon(_animPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 22),
                      onPressed: _frames.length > 1 ? _toggleAnimPlay : null,
                    ),
                    DropdownButton<int>(
                      value: [80, 120, 150, 200, 300, 500].contains(_animDelayMs)
                          ? _animDelayMs
                          : 150,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 80, child: Text('80 ms')),
                        DropdownMenuItem(value: 120, child: Text('120 ms')),
                        DropdownMenuItem(value: 150, child: Text('150 ms')),
                        DropdownMenuItem(value: 200, child: Text('200 ms')),
                        DropdownMenuItem(value: 300, child: Text('300 ms')),
                        DropdownMenuItem(value: 500, child: Text('500 ms')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        final wasPlaying = _animPlaying;
                        if (wasPlaying) _stopAnim();
                        setState(() => _animDelayMs = v);
                        if (wasPlaying) _toggleAnimPlay();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Луковица'),
                      selected: _onionSkin,
                      onSelected: (v) => setState(() => _onionSkin = v),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    IconButton(
                      tooltip: 'Новый слой',
                      icon: const Icon(Icons.layers, size: 20),
                      onPressed: _addLayer,
                    ),
                    IconButton(
                      tooltip: 'Слить с нижним',
                      icon: const Icon(Icons.vertical_align_bottom, size: 20),
                      onPressed: _activeLayerIndex > 0 ? _mergeDown : null,
                    ),
                    IconButton(
                      tooltip: 'Удалить слой',
                      icon: const Icon(Icons.layers_clear, size: 20),
                      onPressed: _currentFrameLayers.length > 1 ? _removeActiveLayer : null,
                    ),
                    const SizedBox(width: 4),
                    ...List<Widget>.generate(_currentFrameLayers.length, (i) {
                      final L = _currentFrameLayers[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: L.visible ? 'Скрыть' : 'Показать',
                              icon: Icon(
                                L.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed: () => setState(() {
                                L.visible = !L.visible;
                                _dirty = true;
                              }),
                            ),
                            ChoiceChip(
                              label: Text(L.name, style: const TextStyle(fontSize: 11)),
                              selected: _activeLayerIndex == i,
                              onSelected: (_) => setState(() => _activeLayerIndex = i),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(constraints.maxWidth - 16, constraints.maxHeight - 16).clamp(120.0, 520.0);
              return Center(
                child: InteractiveViewer(
                  boundaryMargin: const EdgeInsets.all(64),
                  minScale: 0.25,
                  maxScale: 16,
                  child: GestureDetector(
                    onPanDown: (d) {
                      if (_tool != _PixelTool.eyedropper && !_undoPushedForStroke) {
                        _pushUndo();
                        _undoPushedForStroke = true;
                      }
                      _strokeAtLocal(d.localPosition, side);
                    },
                    onPanUpdate: (d) => _strokeAtLocal(d.localPosition, side),
                    onPanEnd: (_) => _undoPushedForStroke = false,
                    onPanCancel: () => _undoPushedForStroke = false,
                    child: CustomPaint(
                      size: Size(side, side),
                      painter: _PixelCanvasPainter(
                        composite: _compositeFrame(_frameIndex),
                        onion: _onionSkin && _frames.length > 1
                            ? _compositeFrame((_frameIndex - 1 + _frames.length) % _frames.length)
                            : null,
                        onionOpacity: 0.38,
                        gridW: _gridW,
                        gridH: _gridH,
                        checkerTransparency: _checkerTransparency,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Отменить',
                  onPressed: _undoStack.isEmpty ? null : _undo,
                  icon: const Icon(Icons.undo, size: 22),
                ),
                IconButton.filledTonal(
                  tooltip: 'Вернуть',
                  onPressed: _redoStack.isEmpty ? null : _redo,
                  icon: const Icon(Icons.redo, size: 22),
                ),
                IconButton.filledTonal(
                  tooltip: 'Зеркало по горизонтали',
                  onPressed: _mirrorHorizontal,
                  icon: const Icon(Icons.swap_horiz, size: 22),
                ),
                IconButton.filledTonal(
                  tooltip: 'Цвет по hex',
                  onPressed: _dialogPickColor,
                  icon: Icon(Icons.palette_outlined, color: _currentColor, size: 22),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Сохранить спрайт в PNG',
                  onPressed: _exportPngCopy,
                  icon: const Icon(Icons.file_download_outlined, size: 22),
                ),
                FilledButton.icon(
                  onPressed: _dirty ? _saveSprite : null,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(cid != null ? 'Сохранить PNG в облако' : 'Сохранить PNG'),
                ),
                const SizedBox(width: 10),
                Text(
                  _dirty ? '●' : '✓',
                  style: TextStyle(
                    fontSize: 12,
                    color: _dirty ? Colors.orangeAccent : Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    );
  }
}

class _PixelCanvasPainter extends CustomPainter {
  final List<List<Color?>> composite;
  final List<List<Color?>>? onion;
  final double onionOpacity;
  final int gridW;
  final int gridH;
  final bool checkerTransparency;

  _PixelCanvasPainter({
    required this.composite,
    this.onion,
    this.onionOpacity = 0.35,
    required this.gridW,
    required this.gridH,
    this.checkerTransparency = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / gridW;
    final cellH = size.height / gridH;
    final light = Paint()..color = const Color(0xFF3a3a42);
    final dark = Paint()..color = const Color(0xFF2a2a30);
    for (int y = 0; y < gridH; y++) {
      for (int x = 0; x < gridW; x++) {
        final rect = Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5);
        final c = composite[y][x];
        final oc = onion != null ? onion![y][x] : null;
        if (c != null) {
          canvas.drawRect(rect, Paint()..color = c);
        } else if (oc != null) {
          final a = (oc.a * onionOpacity).clamp(0.0, 1.0);
          canvas.drawRect(rect, Paint()..color = oc.withValues(alpha: a));
        } else if (checkerTransparency) {
          canvas.drawRect(rect, (x + y).isEven ? light : dark);
        } else {
          canvas.drawRect(rect, Paint()..color = const Color(0xFF1a1a1f));
        }
      }
    }
    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = math.max(0.5, 0.25 * (cellW / 12));
    final showFine = cellW >= 6;
    if (showFine) {
      for (int x = 0; x <= gridW; x++) {
        canvas.drawLine(Offset(x * cellW, 0), Offset(x * cellW, size.height), grid);
      }
      for (int y = 0; y <= gridH; y++) {
        canvas.drawLine(Offset(0, y * cellH), Offset(size.width, y * cellH), grid);
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.grey.shade600,
    );
  }

  @override
  bool shouldRepaint(covariant _PixelCanvasPainter oldDelegate) =>
      oldDelegate.composite != composite ||
      oldDelegate.onion != onion ||
      oldDelegate.onionOpacity != onionOpacity ||
      oldDelegate.gridW != gridW ||
      oldDelegate.gridH != gridH ||
      oldDelegate.checkerTransparency != checkerTransparency;
}
