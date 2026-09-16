import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';

class NeedsYouList extends StatelessWidget {
  const NeedsYouList({super.key, required this.items, required this.onTap});

  final List<NeedsYouItem> items;
  final ValueChanged<NeedsYouItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NEEDS YOU',
          style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
        ),
        const SizedBox(height: 8),
        for (final item in items) ...[
          _NeedsYouRow(item: item, onTap: () => onTap(item)),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _NeedsYouRow extends StatelessWidget {
  const _NeedsYouRow({required this.item, required this.onTap});

  final NeedsYouItem item;
  final VoidCallback onTap;

  Color get _background => switch (item.kind) {
        NeedsYouKind.vote => AppColors.accent100,
        NeedsYouKind.wallet => AppColors.neutral100,
        NeedsYouKind.availability => AppColors.neutral100,
      };

  Color get _border => switch (item.kind) {
        NeedsYouKind.vote => AppColors.accent700.withValues(alpha: 0.18),
        _ => AppColors.text.withValues(alpha: 0.1),
      };

  Color get _dot => switch (item.kind) {
        NeedsYouKind.vote => AppColors.teamGold,
        NeedsYouKind.wallet => AppColors.neutral300,
        NeedsYouKind.availability => AppColors.accent2_100,
      };

  Color get _titleColor => switch (item.kind) {
        NeedsYouKind.vote => AppColors.accent900,
        _ => AppColors.text,
      };

  Color get _metaColor => switch (item.kind) {
        NeedsYouKind.vote => AppColors.accent800,
        _ => AppColors.text.withValues(alpha: 0.55),
      };

  Color get _chevronColor => switch (item.kind) {
        NeedsYouKind.vote => AppColors.accent700,
        _ => AppColors.text.withValues(alpha: 0.4),
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _background,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: _dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTextStyles.body(
                        size: 13,
                        weight: FontWeight.w700,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.meta,
                      style: AppTextStyles.body(
                        size: 11.5,
                        weight: FontWeight.w500,
                        color: _metaColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '›',
                style: AppTextStyles.body(
                  size: 18,
                  weight: FontWeight.w700,
                  color: _chevronColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
