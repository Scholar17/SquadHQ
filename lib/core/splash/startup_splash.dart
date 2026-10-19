import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';

/// The opening splash, over the whole app: [WarmUpAnimation] until
/// [loaded], then it fades out and never comes back. One continuous
/// animation, though the routes underneath move from the session check to
/// the team list. On the web, index.html plays the same animation until
/// Flutter starts, so opening the app is one splash.
///
/// It stays up at least [minRun] so a fast start isn't a flicker, and goes
/// anyway after [maxWait] so a stalled load still reaches the app (which
/// shows its own loading state).
class StartupSplash extends StatefulWidget {
  const StartupSplash({super.key, required this.loaded, required this.child});

  final bool loaded;
  final Widget child;

  static const minRun = Duration(milliseconds: 700);
  static const maxWait = Duration(seconds: 12);

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  Timer? _minRun;
  Timer? _maxWait;
  bool _ranEnough = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _fade.addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _gone = true);
    });
    _minRun = Timer(StartupSplash.minRun, () {
      _ranEnough = true;
      if (widget.loaded) _leave();
    });
    _maxWait = Timer(StartupSplash.maxWait, _leave);
  }

  @override
  void didUpdateWidget(StartupSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loaded && _ranEnough) _leave();
  }

  void _leave() {
    if (!mounted || _gone) return;
    _minRun?.cancel();
    _maxWait?.cancel();
    _fade.forward();
  }

  @override
  void dispose() {
    _minRun?.cancel();
    _maxWait?.cancel();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: FadeTransition(
            opacity: ReverseAnimation(_fade),
            child: const WarmUpScreen(),
          ),
        ),
      ],
    );
  }
}

/// A full screen of [WarmUpAnimation] — the splash, and the app's own
/// loading state.
class WarmUpScreen extends StatelessWidget {
  const WarmUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: const SafeArea(child: Center(child: WarmUpAnimation())),
    );
  }
}

/// A player running after the ball, looping: the free LottieFiles
/// "Dribbling soccer" (Lottie Simple License), recoloured to the app's ink
/// and accent. Laid out as web/index.html's splash draws it — keep the two
/// in step. Still when the device has animations turned off.
class WarmUpAnimation extends StatelessWidget {
  const WarmUpAnimation({super.key});

  static const asset = 'assets/lottie/runner.json';

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 130,
      child: Lottie.asset(
        asset,
        animate: !MediaQuery.of(context).disableAnimations,
        delegates: LottieDelegates(
          values: [
            ValueDelegate.color(const ['**', 'man', '**'], value: AppColors.text),
            ValueDelegate.color(const ['**', 'Shape Layer 1', '**'], value: AppColors.accent),
            ValueDelegate.color(const ['**', 'Shape Layer 2', '**'], value: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
