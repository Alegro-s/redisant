import 'package:flutter/material.dart';

import '../engine/ffi/engine_bridge.dart';
import '../engine/ffi/engine_types.dart';

/// Dev-панель breakpoint / step для BT (волна 10b).
class BtDebugPanel extends StatefulWidget {
  final SceneHandle scene;
  final VoidCallback? onStep;

  const BtDebugPanel({super.key, required this.scene, this.onStep});

  @override
  State<BtDebugPanel> createState() => _BtDebugPanelState();
}

class _BtDebugPanelState extends State<BtDebugPanel> {
  final _breakCtrl = TextEditingController(text: 'leaf_patrol');

  @override
  void dispose() {
    _breakCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'BT debug',
              style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _breakCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Breakpoint path contains',
                labelStyle: TextStyle(fontSize: 11),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                FilledButton(
                  onPressed: () {
                    EngineBridge.sceneSetBtBreakpoint(
                      widget.scene,
                      _breakCtrl.text.trim(),
                    );
                  },
                  child: const Text('Set BP'),
                ),
                OutlinedButton(
                  onPressed: () {
                    EngineBridge.sceneSetBtBreakpoint(widget.scene, '');
                    _breakCtrl.clear();
                  },
                  child: const Text('Clear'),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    EngineBridge.sceneBtDebugStep(widget.scene);
                    widget.onStep?.call();
                  },
                  child: const Text('Step'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
