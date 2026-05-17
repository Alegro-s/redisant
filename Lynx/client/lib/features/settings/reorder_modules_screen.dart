import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/providers/settings_provider.dart';

class ReorderModulesScreen extends StatefulWidget {
  const ReorderModulesScreen({super.key});

  @override
  State<ReorderModulesScreen> createState() => _ReorderModulesScreenState();
}

class _ReorderModulesScreenState extends State<ReorderModulesScreen> {
  late List<Map<String, dynamic>> _modules;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _modules = settings.getVisibleModulesInOrder();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Порядок модулей'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              final newOrder = _modules.map((m) => m['id']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
              settings.updateModulesOrder(newOrder);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _modules.length,
        itemBuilder: (context, index) {
          final module = _modules[index];
          return Card(
            key: ValueKey(module['id']),
            child: ListTile(
              leading: Icon(
                module['icon'] is IconData ? module['icon'] as IconData : Icons.widgets_outlined,
              ),
              title: Text(module['title']?.toString() ?? ''),
            ),
          );
        },
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            if (oldIndex < newIndex) newIndex -= 1;
            final item = _modules.removeAt(oldIndex);
            _modules.insert(newIndex, item);
          });
        },
      ),
    );
  }
}