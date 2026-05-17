import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/providers/portfolio_provider.dart';
import 'sheet_handle.dart';

void showPortfolioCategorySheet(BuildContext context, String section, String item) {
  final portfolio = context.read<PortfolioProvider>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottom = MediaQuery.of(ctx).padding.bottom;
      final matches = portfolio.items
          .where(
            (p) =>
                p.category.toLowerCase().contains(item.toLowerCase()) ||
                p.title.toLowerCase().contains(item.toLowerCase()),
          )
          .toList();
      return Container(
        decoration: const BoxDecoration(
          color: AppConstants.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.sheetTopRadius)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabHandle(),
            Text(
              item,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppConstants.blockBlack),
            ),
            Text(section, style: TextStyle(fontSize: 13, color: AppConstants.secondaryColor)),
            if (matches.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Записи',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ...matches.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.category} · ${p.status}', style: TextStyle(fontSize: 12, color: AppConstants.secondaryColor)),
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Закрыть'),
            ),
          ],
        ),
      );
    },
  );
}
