import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'sheet_parts.dart';
import 'squad_widgets.dart';

/// The kinds of expense "+ Add" can start.
enum AddExpenseType {
  group('Group expense', 'Split with the squad · counts in the squad balance', Icons.groups_outlined),
  trip('Trip expense', 'Something paid on a trip, settled once it ends', Icons.luggage_outlined),
  monthly('Monthly expense', 'A subscription charged every month', Icons.autorenew_rounded),
  buddy('Buddy expense', 'Just you and one squad-mate · only you two see it', Icons.people_outline_rounded),
  personal('Personal expense', 'Your own spending · only you see it', Icons.person_outline_rounded);

  const AddExpenseType(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

/// "What are you adding?" — pick the kind of expense, then its own sheet
/// opens. Null: closed without picking. [tripAvailable] false: no trip is
/// open (and you're not an admin who could start one), so Trip is greyed
/// out with why.
Future<AddExpenseType?> pickExpenseType(BuildContext context, {required bool tripAvailable}) =>
    showModalBottomSheet<AddExpenseType>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              const SheetHeader(title: 'Add expense'),
              Text(
                'What kind of expense is it?',
                style: AppTextStyles.body(size: 13, color: squadMuted),
              ),
              const SizedBox(height: 12),
              for (final type in AddExpenseType.values) ...[
                _TypeTile(
                  type: type,
                  disabledReason: type == AddExpenseType.trip && !tripAvailable
                      ? 'No trip is open — an admin starts one.'
                      : null,
                  onTap: () => Navigator.of(context).pop(type),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type, required this.disabledReason, required this.onTap});

  final AddExpenseType type;

  /// Why it can't be picked right now, or null.
  final String? disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = disabledReason == null;
    final color = enabled ? AppColors.text : AppColors.neutral600;
    return Semantics(
      key: ValueKey('add-expense-${type.name}'),
      button: true,
      enabled: enabled,
      child: Material(
        color: AppColors.bg,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: AppRadius.md),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                  child: Icon(type.icon, size: 20, color: enabled ? AppColors.accent700 : color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label, style: AppTextStyles.body(size: 15, weight: FontWeight.w700, color: color)),
                      const SizedBox(height: 2),
                      Text(
                        disabledReason ?? type.description,
                        style: AppTextStyles.body(size: 12, color: squadMuted),
                      ),
                    ],
                  ),
                ),
                if (enabled) Icon(Icons.chevron_right_rounded, color: squadMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
