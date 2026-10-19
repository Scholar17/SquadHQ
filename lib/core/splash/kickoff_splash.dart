import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// The opening splash, over the whole app: a player dribbling the ball
/// while the app loads, who shoots once [loaded] turns true — then the
/// splash fades out and never comes back. One continuous animation, though
/// the routes underneath move from the session check to the team list.
///
/// It stays up at least [minRun] so a fast start isn't a flicker, and kicks
/// anyway after [maxWait] so a stalled load still reaches the app (which
/// shows its own loading state). With animations turned off on the device,
/// the player stands still and the splash just goes once loaded.
class KickoffSplash extends StatefulWidget {
  const KickoffSplash({super.key, required this.loaded, required this.child});

  final bool loaded;
  final Widget child;

  static const minRun = Duration(milliseconds: 700);
  static const maxWait = Duration(seconds: 12);

  @override
  State<KickoffSplash> createState() => _KickoffSplashState();
}

class _KickoffSplashState extends State<KickoffSplash> with TickerProviderStateMixin {
  late final _run = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final _kick = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  Timer? _minRun;
  Timer? _maxWait;
  bool _ranEnough = false;
  bool _kicking = false;
  bool _gone = false;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.of(context).disableAnimations;
    if (still) {
      _run.stop();
    } else if (!_run.isAnimating && !_kicking) {
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
    if (MediaQuery.of(context).disableAnimations) {
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
    return Material(
      color: AppColors.bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // As web/index.html draws it, so the web's own splash runs
              // straight into this one.
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.teamGold, shape: BoxShape.circle),
                child: Text(
                  'GG',
                  style: AppTextStyles.heading(size: 20, color: AppColors.onLight, height: 1),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _kicking ? 'Kick off!' : 'Warming up…',
                style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: AppColors.textMuted)
                    .copyWith(letterSpacing: 1.2),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 320,
                height: 170,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_run, _kick]),
                  builder: (context, _) => CustomPaint(
                    painter: _PitchPainter(
                      run: _run.value,
                      kick: _kick.value,
                      kicking: _kicking,
                      ink: AppColors.text,
                      kit: AppColors.accent,
                      boot: AppColors.teamGold,
                      ball: AppColors.card,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stick-figure player dribbling, then shooting. [run] loops 0→1 per
/// stride while loading; [kick] runs 0→1 once: plant and wind up
/// (to 0.3), strike (0.3–0.45), the ball flying off to the right.
class _PitchPainter extends CustomPainter {
  _PitchPainter({
    required this.run,
    required this.kick,
    required this.kicking,
    required this.ink,
    required this.kit,
    required this.boot,
    required this.ball,
  });

  final double run;
  final double kick;
  final bool kicking;
  final Color ink;
  final Color kit;
  final Color boot;
  final Color ball;

  static const _ballRadius = 11.0;
  static const _strikeAt = 0.35;

  @override
  void paint(Canvas canvas, Size size) {
    final groundY = size.height * 0.82;
    final ballGroundY = groundY - _ballRadius;
    final stride = run * 2 * math.pi;

    // Ground, and turf marks sliding past while he runs.
    canvas.drawLine(
      Offset(0, groundY),
      Offset(size.width, groundY),
      Paint()
        ..color = ink.withValues(alpha: 0.18)
        ..strokeWidth = 2,
    );
    final turf = Paint()
      ..color = ink.withValues(alpha: 0.08)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final scroll = kicking ? 0.0 : run * 60;
    for (var x = 0.0; x < size.width + 60; x += 60) {
      final markX = x - scroll;
      canvas.drawLine(Offset(markX, groundY + 6), Offset(markX - 12, groundY + 16), turf);
    }

    // Dribbling: the ball a step ahead, nudged on with each stride.
    final runX = size.width * 0.34;
    final dribbleX = runX + 44 + math.sin(stride) * 5;
    var playerX = runX;
    var ballCenter = Offset(dribbleX, ballGroundY);
    var ballAngle = run * 2 * math.pi;

    if (kicking) {
      final plantX = dribbleX - 34;
      // A last step up to the ball, then planted.
      playerX = runX + (plantX - runX) * Curves.easeOut.transform((kick / 0.3).clamp(0.0, 1.0));
      if (kick > _strikeAt) {
        final t = (kick - _strikeAt) / (1 - _strikeAt);
        ballCenter = Offset(
          dribbleX + (size.width - dribbleX + 40) * Curves.easeOutQuad.transform(t),
          ballGroundY - math.sin(t * math.pi * 0.85) * 105,
        );
        ballAngle = t * 14;
        // The strike: a ring where the boot met the ball.
        if (t < 0.3) {
          final ring = t / 0.3;
          canvas.drawCircle(
            Offset(dribbleX, ballGroundY),
            ring * 34,
            Paint()
              ..color = kit.withValues(alpha: (1 - ring) * 0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3,
          );
        }
      }
    }

    _drawBall(canvas, ballCenter, ballAngle);
    _drawPlayer(canvas, playerX, groundY, stride);
  }

  void _drawBall(Canvas canvas, Offset center, double angle) {
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(angle);
    canvas.drawCircle(Offset.zero, _ballRadius, Paint()..color = ball);
    final patch = Paint()..color = ink;
    canvas.drawCircle(Offset.zero, _ballRadius * 0.35, patch);
    for (var i = 0; i < 5; i++) {
      final a = i * 72 * math.pi / 180;
      canvas.drawCircle(
        Offset(math.cos(a) * _ballRadius * 0.85, math.sin(a) * _ballRadius * 0.85),
        _ballRadius * 0.2,
        patch,
      );
    }
    canvas
      ..drawCircle(
        Offset.zero,
        _ballRadius,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..restore();
  }

  void _drawPlayer(Canvas canvas, double x, double groundY, double stride) {
    // Angles from straight down; positive swings forward (to the right).
    double kickLeg, standLeg, frontArm, backArm;
    var lean = 0.22;
    var bob = 0.0;

    if (!kicking) {
      kickLeg = math.sin(stride) * 0.8;
      standLeg = -kickLeg;
      frontArm = -kickLeg * 0.85;
      backArm = -frontArm;
      bob = math.sin(stride * 2).abs() * 5;
    } else if (kick < 0.3) {
      // Wind-up: the kicking leg draws back, arms out for balance.
      final t = kick / 0.3;
      kickLeg = -math.sin(t * math.pi / 2);
      standLeg = 0.15;
      frontArm = 0.7;
      backArm = -0.7;
      lean = 0.32;
    } else {
      // Strike and follow-through.
      final t = Curves.easeOutBack.transform(((kick - 0.3) / 0.7).clamp(0.0, 1.0));
      kickLeg = -1 + t * 2.2;
      standLeg = 0.1;
      frontArm = -0.6;
      backArm = 0.6;
      lean = 0.05;
    }

    final hip = Offset(x, groundY - 44 - bob);
    final shoulder = Offset(hip.dx + math.sin(lean) * 34, hip.dy - math.cos(lean) * 34);
    final head = Offset(shoulder.dx + math.sin(lean) * 15, shoulder.dy - math.cos(lean) * 15);

    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final limb = stroke(kit, 6);
    final far = stroke(kit.withValues(alpha: 0.55), 6);

    _arm(canvas, far, shoulder, backArm);
    _leg(canvas, far, hip, standLeg);
    canvas
      ..drawLine(hip, shoulder, stroke(ink, 7))
      ..drawCircle(head, 9.5, Paint()..color = ink);
    _leg(canvas, stroke(boot, 6), hip, kickLeg);
    _arm(canvas, limb, shoulder, frontArm);
  }

  void _leg(Canvas canvas, Paint paint, Offset hip, double angle) {
    const thigh = 22.0, calf = 22.0;
    final knee = Offset(hip.dx + math.sin(angle) * thigh, hip.dy + math.cos(angle) * thigh);
    final bend = angle + (angle > 0 ? 0.3 : 0.6);
    final foot = Offset(knee.dx + math.sin(bend) * calf, knee.dy + math.cos(bend) * calf);
    canvas
      ..drawLine(hip, knee, paint)
      ..drawLine(knee, foot, paint);
  }

  void _arm(Canvas canvas, Paint paint, Offset shoulder, double angle) {
    const upper = 17.0, lower = 15.0;
    final elbow = Offset(shoulder.dx + math.sin(angle) * upper, shoulder.dy + math.cos(angle) * upper);
    final hand = Offset(elbow.dx + math.sin(angle + 0.4) * lower, elbow.dy + math.cos(angle + 0.4) * lower);
    canvas
      ..drawLine(shoulder, elbow, paint)
      ..drawLine(elbow, hand, paint);
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.run != run || old.kick != kick || old.kicking != kicking || old.ink != ink;
}
