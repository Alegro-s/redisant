import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/providers/student_provider.dart';

class ProfileCard extends StatelessWidget {
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onRefreshPressed;

  const ProfileCard({
    super.key,
    this.onSettingsPressed,
    this.onRefreshPressed,
  });

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final student = studentProvider.student;

    if (student == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.surfaceMuted,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(color: AppConstants.blockBlack, strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppConstants.blockBlack,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppConstants.blockBlackElevated,
            backgroundImage:
                student.avatarUrl != null ? NetworkImage(student.avatarUrl!) : null,
            child: student.avatarUrl == null
                ? Icon(PhosphorIconsRegular.user, size: 24, color: AppConstants.onBlockSecondary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppConstants.onBlock,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${student.group} · курс ${student.course}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppConstants.onBlockSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSettingsPressed != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(PhosphorIconsRegular.gear, color: AppConstants.onBlock, size: 22),
                  onPressed: onSettingsPressed,
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(PhosphorIconsRegular.arrowsClockwise, color: AppConstants.onBlock, size: 22),
                onPressed: onRefreshPressed ?? () => studentProvider.loadStudentData(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
