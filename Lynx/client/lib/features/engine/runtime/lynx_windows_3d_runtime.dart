/// Windows Player 3D runtime (Q3).
enum LynxWindows3dRuntime {
  /// Flutter Canvas overlay (`Game3dPlayOverlay`).
  canvasPreview,

  /// D3D12 forward3D child HWND (`lynx_viewport_*` FFI).
  coreForwardD3d12,
}

extension LynxWindows3dRuntimeJson on LynxWindows3dRuntime {
  String get jsonValue => switch (this) {
        LynxWindows3dRuntime.canvasPreview => 'canvas_preview',
        LynxWindows3dRuntime.coreForwardD3d12 => 'core_forward_d3d12',
      };

  static LynxWindows3dRuntime fromJson(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'core_forward_d3d12':
      case 'core_forward':
      case 'd3d12':
        return LynxWindows3dRuntime.coreForwardD3d12;
      case 'canvas_preview':
      case 'canvas':
      case null:
      case '':
        return LynxWindows3dRuntime.canvasPreview;
      default:
        return LynxWindows3dRuntime.canvasPreview;
    }
  }
}
