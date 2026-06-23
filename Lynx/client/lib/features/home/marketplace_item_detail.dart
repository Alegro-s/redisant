import 'package:flutter/material.dart';

import '../ecosystem/lynx_marketplace.dart';
import '../../app/widgets/lynx_xbox_tile.dart';

Future<void> openMarketplaceItemDetail(
  BuildContext context, {
  required LynxMarketplaceItem item,
  required VoidCallback onPrimaryAction,
  String primaryActionLabel = 'Установить',
}) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: _MarketplaceItemDetailBody(
            item: item,
            onPrimaryAction: () {
              Navigator.pop(ctx);
              onPrimaryAction();
            },
            primaryActionLabel: primaryActionLabel,
          ),
        ),
      ),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        appBar: AppBar(
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(ctx),
          ),
        ),
        body: _MarketplaceItemDetailBody(
          item: item,
          onPrimaryAction: () {
            Navigator.pop(ctx);
            onPrimaryAction();
          },
          primaryActionLabel: primaryActionLabel,
        ),
      ),
    ),
  );
}

class _MarketplaceItemDetailBody extends StatelessWidget {
  const _MarketplaceItemDetailBody({
    required this.item,
    required this.onPrimaryAction,
    required this.primaryActionLabel,
  });

  final LynxMarketplaceItem item;
  final VoidCallback onPrimaryAction;
  final String primaryActionLabel;

  String get _kindLabel {
    switch (item.kind) {
      case 'game':
        return 'Игра';
      case 'template':
        return 'Шаблон';
      case 'plugin':
        return 'Плагин';
      case 'engine_core':
        return 'Ядро';
      default:
        return item.category.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final desc = item.description?.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Center(
          child: LynxXboxTile(
            title: item.title,
            subtitle: item.author,
            imageUrl: item.imageUrl,
            icon: item.category == '3d'
                ? Icons.view_in_ar_outlined
                : Icons.extension_outlined,
            badge: _kindLabel.toUpperCase(),
            width: 220,
            height: 260,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metaChip(context, _kindLabel),
            _metaChip(context, item.category),
            if (item.version != null) _metaChip(context, 'v${item.version}'),
            if (item.price != null && item.price! > 0)
              _metaChip(context, '${item.price!.toStringAsFixed(0)} ₽'),
            if (item.builtin) _metaChip(context, 'Встроенный'),
          ],
        ),
        if (item.author != null && item.author!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Автор',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(item.author!, style: const TextStyle(fontSize: 15)),
        ],
        if (item.rating != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.star_outline, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text('${item.rating!.toStringAsFixed(1)} / 5'),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          'Описание',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          desc != null && desc.isNotEmpty
              ? desc
              : 'Пакет «${item.title}» для Lynx. Установите в проект или создайте новый из шаблона.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: cs.onSurface.withValues(alpha: 0.92),
          ),
        ),
        if (item.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Теги',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in item.tags)
                Chip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ],
        if (item.engineMinVersion != null) ...[
          const SizedBox(height: 12),
          Text(
            'Минимальная версия движка: ${item.engineMinVersion}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onPrimaryAction,
          icon: Icon(
            item.kind == 'template'
                ? Icons.add_box_outlined
                : Icons.download_outlined,
          ),
          label: Text(primaryActionLabel),
        ),
      ],
    );
  }

  Widget _metaChip(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface),
      ),
    );
  }
}
