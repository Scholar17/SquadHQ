import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The opening splash, over the whole app: a player running after the ball
/// while the app loads, then a volley once [loaded] turns true — then the
/// splash fades out and never comes back. One continuous animation, though
/// the routes underneath move from the session check to the team list.
///
/// Both are free LottieFiles animations (assets/lottie/): "Dribbling
/// soccer", recoloured to the app's ink and accent, and "Soccer player kick
/// on the ball".
///
/// It stays up at least [minRun] so a fast start isn't a flicker, and kicks
/// anyway after [maxWait] so a stalled load still reaches the app (which
/// shows its own loading state). With animations turned off on the device,
/// nothing moves and the splash just goes once loaded.
class KickoffSplash extends StatefulWidget {
  const KickoffSplash({super.key, required this.loaded, required this.child});

  final bool loaded;
  final Widget child;

  static const minRun = Duration(milliseconds: 700);
  static const maxWait = Duration(seconds: 12);

  /// The volley plays faster than drawn: it's the last thing before the app.
  static const kickSpeed = 1.5;

  @override
  State<KickoffSplash> createState() => _KickoffSplashState();
}

class _KickoffSplashState extends State<KickoffSplash> with TickerProviderStateMixin {
  late final _run = AnimationController(vsync: this);
  late final _kick = AnimationController(vsync: this);
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  LottieComposition? _runner;
  LottieComposition? _volley;
  Timer? _minRun;
  Timer? _maxWait;
  bool _ranEnough = false;
  bool _kicking = false;
  bool _gone = false;

  /// Animations turned off on the device (kept from MediaQuery).
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _kick.addStatusListener((status) {
      if (status == AnimationStatus.completed) _fade.forward();
    });
    _fade.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _run.stop();
        setState(() => _gone = true);
      }
    });
    _minRun = Timer(KickoffSplash.minRun, () {
      _ranEnough = true;
      if (widget.loaded) _startKick();
    });
    _maxWait = Timer(KickoffSplash.maxWait, _startKick);
    // Not inside initState: a cached animation loads synchronously.
    scheduleMicrotask(_load);
  }

  Future<void> _load() async {
    final runner = await AssetLottie('assets/lottie/runner.json').load();
    final volley = await AssetLottie('assets/lottie/kick.json').load();
    if (!mounted) return;
    setState(() {
      _runner = runner;
      _volley = volley;
    });
    _run.duration = runner.duration;
    _kick.duration = volley.duration * (1 / KickoffSplash.kickSpeed);
    if (!_kicking && !_still) _run.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    if (_still) {
      _run.stop();
    } else if (_runner != null && !_run.isAnimating && !_kicking) {
      _run.repeat();
    }
  }

  @override
  void didUpdateWidget(KickoffSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loaded && _ranEnough) _startKick();
  }

  void _startKick() {
    if (!mounted || _kicking || _gone) return;
    _minRun?.cancel();
    _maxWait?.cancel();
    setState(() => _kicking = true);
    _run.stop();
    // Not loaded yet (or nothing should move): straight to the app.
    if (_volley == null || _still) {
      _fade.forward();
    } else {
      _kick.forward();
    }
  }

  @override
  void dispose() {
    _minRun?.cancel();
    _maxWait?.cancel();
    _run.dispose();
    _kick.dispose();
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
            child: _scene(),
          ),
        ),
      ],
    );
  }

  Widget _scene() {
    final runner = _runner;
    final volley = _volley;
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 280,
                height: 220,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch ((_kicking, runner, volley)) {
                    // Mirrored: drawn shooting to the left, the runner
                    // heads right.
                    (true, _, final volley?) => Transform.flip(
                      key: const ValueKey('kick'),
                      flipX: true,
                      child: Lottie(composition: volley, controller: _kick),
                    ),
                    // The runner fills little of its canvas.
                    (false, final runner?, _) => Transform.scale(
                      key: const ValueKey('run'),
                      scale: 1.5,
                      child: Lottie(
                        composition: runner,
                        controller: _run,
                        delegates: LottieDelegates(
                          values: [
                            ValueDelegate.color(const ['**', 'man', '**'], value: AppColors.text),
                            ValueDelegate.color(const ['**', 'Shape Layer 1', '**'], value: AppColors.accent),
                            ValueDelegate.color(const ['**', 'Shape Layer 2', '**'], value: AppColors.accent),
                          ],
                        ),
                      ),
                    ),
                    _ => const SizedBox.shrink(),
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _kicking ? 'Kick off!' : 'Warming up…',
                style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: AppColors.textMuted)
                    .copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
