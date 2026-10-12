import 'package:flutter/material.dart';

import '../app_colors.dart';

/// A bottom sheet's body with its primary action pinned to the bottom:
/// the [children] scroll, the [action] (with an optional [summary] above
/// it and [footer] line under it) stays in reach — above the keyboard when it's up, above the
/// home indicator when it isn't. While there's more form below, the
/// content fades out into the action bar so the cut reads as "scroll".
///
/// Use inside a `showModalBottomSheet(isScrollControlled: true)`.
class StickyActionSheet extends StatefulWidget {
  const StickyActionSheet({
    super.key,
    required this.children,
    required this.action,
    this.summary,
    this.footer,
    this.background,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 12),
    this.maxHeightFactor = 0.92,
    this.expand = false,
  });

  final List<Widget> children;
  final Widget action;

  /// Stays in view with the action — e.g. a live "each pays ฿250" preview,
  /// so the result of each edit shows wherever the form is scrolled.
  final Widget? summary;
  final Widget? footer;

  /// The sheet's own colour — the fade blends into it. Defaults to
  /// [AppColors.bg].
  final Color? background;
  final EdgeInsets padding;

  /// Of the screen height, so a long form leaves the page peeking above.
  final double maxHeightFactor;

  /// A whole page's body rather than a sheet's: fills the space it's given
  /// with the action at the very bottom. The [Scaffold] already lifts it
  /// above the keyboard.
  final bool expand;

  @override
  State<StickyActionSheet> createState() => _StickyActionSheetState();
}

class _StickyActionSheetState extends State<StickyActionSheet> {
  bool _moreBelow = false;

  bool _update(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final more = metrics.pixels < metrics.maxScrollExtent - 1;
    if (more != _moreBelow) setState(() => _moreBelow = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.background ?? AppColors.bg;
    final media = MediaQuery.of(context);
    final keyboard = widget.expand ? 0.0 : media.viewInsets.bottom;
    // The keyboard covers the home indicator; without it, clear the inset.
    final bottomGap = keyboard > 0 ? 12.0 : media.viewPadding.bottom + 12;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: widget.expand
            ? const BoxConstraints()
            : BoxConstraints(maxHeight: (media.size.height - keyboard) * widget.maxHeightFactor),
        child: Column(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              fit: widget.expand ? FlexFit.tight : FlexFit.loose,
              child: Stack(
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (notification) => _update(notification.metrics),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) => _update(notification.metrics),
                      child: ListView(
                        shrinkWrap: !widget.expand,
                        padding: widget.padding,
                        children: widget.children,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 28,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _moreBelow ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [background.withValues(alpha: 0), background],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                border: Border(
                  top: BorderSide(
                    // A hairline only while content runs underneath.
                    color: _moreBelow ? AppColors.divider : background.withValues(alpha: 0),
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  widget.padding.left,
                  10,
                  widget.padding.right,
                  bottomGap,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.summary case final summary?) ...[
                      summary,
                      const SizedBox(height: 10),
                    ],
                    widget.action,
                    if (widget.footer case final footer?) ...[const SizedBox(height: 8), footer],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
