import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/constants.dart';
import '../../data/services/showcase_content_store.dart';
import 'sheet_handle.dart';

Future<bool?> showShowcaseNewsEditorSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ShowcaseNewsEditorSheet(),
  );
}

class _ShowcaseNewsEditorSheet extends StatefulWidget {
  const _ShowcaseNewsEditorSheet();

  @override
  State<_ShowcaseNewsEditorSheet> createState() => _ShowcaseNewsEditorSheetState();
}

class _ShowcaseNewsEditorSheetState extends State<_ShowcaseNewsEditorSheet> {
  final List<_Draft> _drafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final custom = await ShowcaseContentStore.loadCustomSlides();
    if (!mounted) return;
    setState(() {
      _drafts.clear();
      if (custom.isEmpty) {
        _drafts.add(_Draft());
      } else {
        for (final s in custom) {
          _drafts.add(_Draft.fromSlide(s));
        }
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final slides = _drafts
        .map((d) => d.toSlide())
        .where((s) => s.title.trim().isNotEmpty)
        .toList();
    await ShowcaseContentStore.saveCustomSlides(slides);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _reset() async {
    await ShowcaseContentStore.resetToDefaults();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: AppConstants.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppConstants.blockBlack))
              : ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    const SheetGrabHandle(),
                    const Text(
                      'Новости витрины',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Оранжевый блок на вкладке «Витрина». Пустой список — стандартные слайды.',
                      style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _drafts.length; i++) ...[
                      _DraftCard(
                        index: i,
                        draft: _drafts[i],
                        onRemove: _drafts.length > 1
                            ? () => setState(() => _drafts.removeAt(i))
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _drafts.add(_Draft())),
                      icon: const Icon(PhosphorIconsRegular.plus),
                      label: const Text('Добавить новость'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppConstants.blockBlack,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Сохранить'),
                    ),
                    TextButton(
                      onPressed: _reset,
                      child: const Text('Вернуть стандартные слайды'),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _Draft {
  _Draft({String? tag, String? title, String? subtitle})
      : tag = TextEditingController(text: tag ?? ''),
        title = TextEditingController(text: title ?? ''),
        subtitle = TextEditingController(text: subtitle ?? '');

  factory _Draft.fromSlide(ShowcaseHeroSlide s) => _Draft(
        tag: s.tag,
        title: s.title,
        subtitle: s.subtitle,
      );

  final TextEditingController tag;
  final TextEditingController title;
  final TextEditingController subtitle;

  ShowcaseHeroSlide toSlide() => ShowcaseHeroSlide(
        tag: tag.text.trim().isEmpty ? 'Новость' : tag.text.trim(),
        title: title.text.trim(),
        subtitle: subtitle.text.trim(),
        colors: const [Color(0xFF3A2520), AppConstants.terracottaDark, AppConstants.terracotta],
      );
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.index, required this.draft, this.onRemove});

  final int index;
  final _Draft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppConstants.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Новость ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(PhosphorIconsRegular.trash, size: 20),
                ),
            ],
          ),
          TextField(
            controller: draft.tag,
            decoration: const InputDecoration(labelText: 'Метка (бейдж)', isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.title,
            decoration: const InputDecoration(labelText: 'Заголовок', isDense: true),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: draft.subtitle,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Подзаголовок', isDense: true),
          ),
        ],
      ),
    );
  }
}
