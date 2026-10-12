import 'package:flutter/widgets.dart';

/// Fades the ends of a horizontal scroller (a chip row) where there's
/// more to scroll to — a hint that it scrolls, without a hard cut-off.
/// Each end fades only while content is hidden past it.
class EdgeFade extends StatefulWidget {
  const EdgeFade({super.key, required this.child, this.fadeWidth = 28});

  /// A horizontally scrolling widget, e.g. a [ListView].
  final Widget child;
  final double fadeWidth;

  @override
  State<EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<EdgeFade> {
  bool _moreBefore = false;
  bool _moreAfter = false;

  bool _update(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return false;
    final before = metrics.pixels > metrics.minScrollExtent + 0.5;
    final after = metrics.pixels < metrics.maxScrollExtent - 0.5;
    if (before != _moreBefore || after != _moreAfter) {
      setState(() {
        _moreBefore = before;
        _moreAfter = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    const opaque = Color(0xFF000000);
    const clear = Color(0x00000000);
    return NotificationListener<ScrollMetricsNotification>(
      // Fires on first layout and on resize — catches a row that
      // overflows before anyone scrolls it.
      onNotification: (notification) => _update(notification.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _update(notification.metrics),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final stop = (widget.fadeWidth / bounds.width).clamp(0.0, 0.5);
            return LinearGradient(
              colors: [_moreBefore ? clear : opaque, opaque, opaque, _moreAfter ? clear : opaque],
              stops: [0, stop, 1 - stop, 1],
            ).createShader(bounds);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
