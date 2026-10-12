import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Makes [child] feel pressable: it eases down to [scale] while a finger
/// is on it and springs back on release, with a light haptic tick on tap.
///
/// Doesn't handle the tap itself beyond [onTap] — wrap a card or button
/// that has no ink of its own, or pass the button's handler here. With
/// [onTap] null it's inert, so a disabled control doesn't bounce.
class BounceTap extends StatefulWidget {
  const BounceTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.98,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// How far it shrinks while pressed.
  final double scale;

  /// Whether a tap gives a light haptic tick — off for taps that already
  /// make their own (e.g. a system dialog).
  final bool haptic;

  @override
  State<BounceTap> createState() => _BounceTapState();
}

class _BounceTapState extends State<BounceTap> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  void _handleTap() {
    if (widget.haptic) HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled ? _handleTap : null,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? widget.scale : 1,
        // Quick down, a little overshoot on the way back up.
        duration: Duration(milliseconds: _pressed ? 90 : 220),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
