import 'package:flutter/widgets.dart';

import 'lynx_3d_codec.dart';

/// Web / non-Windows stub (Q3).
class Lynx3dCoreViewport extends StatelessWidget {
  const Lynx3dCoreViewport({
    super.key,
    required this.extension,
    this.projectPath,
    this.orbitYaw = 0,
    this.orbitPitch = 0.35,
    this.simulatePhysics = true,
  });

  final Lynx3dSceneExtension extension;
  final String? projectPath;
  final double orbitYaw;
  final double orbitPitch;
  final bool simulatePhysics;

  static bool get isPlatformSupported => false;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
