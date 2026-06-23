import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants.dart';
import '../../data/services/api_service.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key, required this.adminToken});

  final String adminToken;

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _api.adminFetchSchedule(widget.adminToken);
      setState(() {
        _items = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.adminSaveSchedule(widget.adminToken, _items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Расписание сохранено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addItem() {
    final now = DateTime.now().toUtc();
    setState(() {
      _items.add({
        'id': 'NEW-${_items.length + 1}',
        'subject': 'Новая дисциплина',
        'teacher': '',
        'classroom': '',
        'startTime': now.toIso8601String(),
        'endTime': now.add(const Duration(hours: 1, minutes: 35)).toIso8601String(),
        'type': 'лекция',
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ: расписание'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(PhosphorIconsRegular.arrowsClockwise)),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(PhosphorIconsRegular.floppyDisk),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        backgroundColor: AppConstants.blockBlack,
        icon: const Icon(PhosphorIconsRegular.plus),
        label: const Text('Занятие'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.blockBlack))
          : _error != null
              ? Center(child: Text(_error!, textAlign: TextAlign.center))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ScheduleEditCard(
                    data: _items[i],
                    onChanged: (v) => setState(() => _items[i] = v),
                    onDelete: () => setState(() => _items.removeAt(i)),
                  ),
                ),
    );
  }
}

class _ScheduleEditCard extends StatelessWidget {
  const _ScheduleEditCard({
    required this.data,
    required this.onChanged,
    required this.onDelete,
  });

  final Map<String, dynamic> data;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse('${data['startTime']}')?.toLocal();
    final timeLabel = start != null ? DateFormat('EEE dd.MM HH:mm', 'ru_RU').format(start) : '—';

    return Material(
      color: AppConstants.surfaceMuted,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(timeLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(onPressed: onDelete, icon: const Icon(PhosphorIconsRegular.trash, size: 20)),
              ],
            ),
            _field('Предмет', data['subject'], (v) => onChanged({...data, 'subject': v})),
            _field('Преподаватель', data['teacher'], (v) => onChanged({...data, 'teacher': v})),
            _field('Аудитория', data['classroom'], (v) => onChanged({...data, 'classroom': v})),
            _field('Тип', data['type'], (v) => onChanged({...data, 'type': v})),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, dynamic value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        initialValue: '$value',
        decoration: InputDecoration(labelText: label, isDense: true, filled: true, fillColor: Colors.white),
        onChanged: onChanged,
      ),
    );
  }
}
