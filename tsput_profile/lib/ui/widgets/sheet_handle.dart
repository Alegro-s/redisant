import 'package:flutter/material.dart';

import '../../core/constants.dart';

class SheetGrabHandle extends StatelessWidget {
  const SheetGrabHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppConstants.sheetHandle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
