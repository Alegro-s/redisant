import 'dart:io';

import 'package:path/path.dart' as p;

/// Bundled templates/carts next to LynxLauncher.exe (MSI: templates/, arcade/).
class ArcadeLocalResolver {
  static String? launcherInstallDir() {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return null;
    try {
      return File(Platform.resolvedExecutable).parent.path;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> resolveBundledCartFile(String cartId) async {
    final root = launcherInstallDir();
    if (root == null || cartId.isEmpty) return null;
    final candidates = [
      p.join(root, 'arcade', '$cartId.lynxcart'),
      p.join(root, 'arcade', cartId, '$cartId.lynxcart'),
    ];
    for (final c in candidates) {
      if (await File(c).exists()) return c;
    }
    return null;
  }

  static Future<String?> resolveBundledTemplateProject(String templateId) async {
    if (templateId.isEmpty) return null;
    final root = launcherInstallDir();
    if (root == null) return null;
    final candidates = [
      p.join(root, 'templates', templateId),
      p.join(root, '..', 'templates', templateId),
    ];
    for (final dir in candidates) {
      final pj = File(p.join(dir, 'project.json'));
      if (await pj.exists()) return p.normalize(dir);
    }
    return null;
  }

  /// Maps catalog ids to template folder names.
  static String? templateIdForCart(String cartId) {
    switch (cartId) {
      case 'lynx-tetris':
        return 'lynx-tetris';
      case 'tetris-demo':
      case 'game-tetris-demo':
        return 'tetris-demo';
      case 'game-wave2':
        return 'platformer-wave2';
      default:
        return cartId;
    }
  }
}
