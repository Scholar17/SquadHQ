import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';
import '../app_shadows.dart';
import '../app_text_styles.dart';

/// A step in an [EmptyState]'s "what to do next" list.
typedef EmptyStateStep = ({IconData icon, String text});

/// A whole screen with nothing on it yet: an illustrated badge, what's
/// missing and why, optional next [steps], and the one action that fixes
/// it. Settles in with a short rise-and-fade.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.steps = const [],
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<EmptyStateStep> steps;

  /// No label, no button — for a viewer who can't fix it themselves.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Badge(icon: icon),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.heading(size: 22)),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 13.5, color: AppColors.textMuted, height: 1.5),
        ),
        if (steps.isNotEmpty) ...[const SizedBox(height: 20), _Steps(steps: steps)],
        if (actionLabel != null) ...[
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onDark,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(
                actionLabel,
                style: AppTextStyles.title(size: 14, color: AppColors.onDark),
              ),
            ),
          ),
        ],
      ],
    );
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: MediaQuery.disableAnimationsOf(context)
            ? content
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
                ),
                child: content,
              ),
      ),
    );
  }
}

/// The illustration: a gold medallion in two soft halo rings, with a few
/// confetti dots in the brand colours around it.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _ring(132, 0.10),
            _ring(100, 0.18),
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.teamGold,
                shape: BoxShape.circle,
                boxShadow: AppShadows.darkHeroGlow,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.neutral800, size: 32),
            ),
            const Positioned(top: 10, right: 18, child: _Dot(size: 10, color: AppColors.accent)),
            const Positioned(bottom: 16, left: 12, child: _Dot(size: 8, color: AppColors.accent2)),
            const Positioned(top: 30, left: 6, child: _Dot(size: 6, color: AppColors.accent400)),
            const Positioned(bottom: 6, right: 30, child: _Dot(size: 6, color: AppColors.teamGold)),
          ],
        ),
      ),
    );
  }

  Widget _ring(double size, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.teamGold.withValues(alpha: alpha),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<EmptyStateStep> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          for (final (index, step) in steps.indexed) ...[
            if (index > 0) Divider(height: 1, color: AppColors.text.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent100,
                      borderRadius: AppRadius.sm,
                    ),
                    child: Icon(step.icon, size: 18, color: AppColors.accent700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.text,
                      style: AppTextStyles.body(size: 13, weight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
