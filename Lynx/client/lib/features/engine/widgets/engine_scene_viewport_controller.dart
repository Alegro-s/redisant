import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Команды масштаба/сброса холста сцены (из горячих клавиш редактора).
class EngineSceneViewportController extends ChangeNotifier {
  double _pendingZoomFactor = 1.0;
  bool _pendingReset = false;
  Matrix4 _matrix = Matrix4.identity();
  Size _viewportSize = Size.zero;
  Offset? _pendingFocusScenePoint;

  Matrix4 get viewportMatrix => _matrix;
  Size get viewportSize => _viewportSize;

  void reportViewport(Matrix4 matrix, Size size) {
    _matrix = Matrix4.copy(matrix);
    _viewportSize = size;
    notifyListeners();
  }

  void focusScenePoint(Offset scenePoint) {
    _pendingFocusScenePoint = scenePoint;
    notifyListeners();
  }

  Offset? consumeFocusScenePoint() {
    final v = _pendingFocusScenePoint;
    _pendingFocusScenePoint = null;
    return v;
  }

  double consumeZoomFactor() {
    final v = _pendingZoomFactor;
    _pendingZoomFactor = 1.0;
    return v;
  }

  bool consumeReset() {
    final v = _pendingReset;
    _pendingReset = false;
    return v;
  }

  void zoomIn({double factor = 1.12}) {
    _pendingZoomFactor = factor;
    notifyListeners();
  }

  void zoomOut({double factor = 1 / 1.12}) {
    _pendingZoomFactor = factor;
    notifyListeners();
  }

  void resetView() {
    _pendingReset = true;
    notifyListeners();
  }
}
