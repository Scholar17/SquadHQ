import 'package:flutter/material.dart';

import '../app_colors.dart';

/// The widest the app's column gets. Past this (tablets, desktop web)
/// lines grow too long to read and cards too wide to scan.
const kMaxContentWidth = 560.0;

/// Holds the whole app — pages, sheets, dialogs — to [kMaxContentWidth],
/// centred on a quiet backdrop, and tells everything inside that the
/// screen is that wide so width-based layouts measure the column. On a
/// phone it's a no-op.
///
/// Used as `MaterialApp.builder`.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= kMaxContentWidth) return child;
        final media = MediaQuery.of(context);
        return ColoredBox(
          color: AppColors.surface,
          child: Center(
            child: Container(
              width: kMaxContentWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.bg,
                border: Border.symmetric(vertical: BorderSide(color: AppColors.divider)),
              ),
              child: MediaQuery(
                data: media.copyWith(size: Size(kMaxContentWidth, media.size.height)),
                child: ClipRect(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Caps a single page's content at [maxWidth], centred — for a screen
/// that wants a narrower column than the app's (a form, a dialog body).
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({super.key, required this.child, this.maxWidth = kMaxContentWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
