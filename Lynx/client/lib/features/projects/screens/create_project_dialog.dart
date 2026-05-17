import 'package:flutter/material.dart';

class CreateProjectDialog extends StatefulWidget {
  final Function(String name, String? description, String visibility) onCreate;
  const CreateProjectDialog({super.key, required this.onCreate});

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _visibility = 'private';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый проект'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название проекта'),
              validator: (v) => (v?.isEmpty ?? true) ? 'Введите название' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Описание (необязательно)'),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _visibility,
              items: const [
                DropdownMenuItem(value: 'private', child: Text('Приватный')),
                DropdownMenuItem(value: 'public', child: Text('Публичный')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _visibility = v);
              },
              decoration: const InputDecoration(labelText: 'Видимость'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onCreate(_nameController.text, _descController.text.isNotEmpty ? _descController.text : null, _visibility);
              Navigator.pop(context);
            }
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}