import 'package:flutter/material.dart';

import '../ffi/engine_bridge.dart';
import '../ffi/engine_types.dart';
import 'lynx_graph_model.dart';

/// E23b — live debug LynxGraph/BT в Play.
class LynxGraphLiveDebugPanel extends StatefulWidget {
  const LynxGraphLiveDebugPanel({
    super.key,
    required this.scene,
    this.graph,
    this.onStep,
  });

  final SceneHandle scene;
  final LynxGraphDocument? graph;
  final VoidCallback? onStep;

  @override
  State<LynxGraphLiveDebugPanel> createState() => _LynxGraphLiveDebugPanelState();
}

class _LynxGraphLiveDebugPanelState extends State<LynxGraphLiveDebugPanel> {
  final _breakCtrl = TextEditingController(text: 'leaf_patrol');
  String? _lastActiveNode;

  @override
  void dispose() {
    _breakCtrl.dispose();
    super.dispose();
  }

  void _refreshActiveNode() {
    final events = EngineBridge.sceneDrainBtDebug(widget.scene);
    final path = events.isNotEmpty ? events.last['path']?.toString() : null;
    if (path != _lastActiveNode && mounted) {
      setState(() => _lastActiveNode = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final graphNodes = widget.graph?.statements.length ?? 0;
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
              'LynxGraph live',
              style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
            ),
            if (graphNodes > 0)
              Text(
                'Узлов в графе: $graphNodes',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            if (_lastActiveNode != null && _lastActiveNode!.isNotEmpty)
              Text(
                'Active: $_lastActiveNode',
                style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 11),
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
                    EngineBridge.sceneSetBtBreakpoint(widget.scene, _breakCtrl.text.trim());
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
                    _refreshActiveNode();
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
