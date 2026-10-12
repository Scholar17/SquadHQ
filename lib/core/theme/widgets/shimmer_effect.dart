import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_radius.dart';

/// Sweeps a soft highlight across every [SkeletonBox] below it, so a
/// loading screen reads as "on its way" rather than frozen. One
/// [Shimmer] per skeleton keeps the boxes moving in step.
///
/// Holds still when the platform asks for reduced motion.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        // Paints over the boxes' own pixels only — the gaps stay clear.
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.neutral300, AppColors.neutral200, AppColors.neutral300],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

/// Slides the gradient from one card-width off the left edge to one off
/// the right as [progress] runs 0 → 1.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.progress);

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
}

/// A placeholder block standing in for a line of text, an avatar or a
/// button while the real thing loads. Put it under a [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = AppRadius.xs});

  /// A circle of [size] — avatars and icons.
  const SkeletonBox.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = AppRadius.pill;

  /// Null stretches to fill the row.
  final double? width;
  final double height;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: AppColors.neutral300, borderRadius: radius),
    );
  }
}
