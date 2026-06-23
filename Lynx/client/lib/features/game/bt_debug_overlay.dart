import 'package:flutter/material.dart';

/// Overlay активных узлов Behavior Tree (волна 10a).
class BtDebugOverlay extends StatelessWidget {
  final List<Map<String, dynamic>> entries;

  const BtDebugOverlay({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final active = entries.where((e) => e['running'] == true).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 8,
      top: 56,
      child: Material(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BT active',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                for (final e in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${e['entity_name'] ?? e['entity_id']}: '
                      '${e['node_type']} · ${e['path']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
