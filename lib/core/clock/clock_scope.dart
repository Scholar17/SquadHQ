import 'dart:async';

import 'package:flutter/widgets.dart';

/// Provides "now" to widgets that change with the time of day — e.g. a
/// match moving to Home's recaps once it finishes — and rebuilds them as
/// it ticks, even when no data changed.
class ClockScope extends StatefulWidget {
  const ClockScope({
    super.key,
    required this.child,
    this.tick = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration tick;

  /// The current time, rebuilding [context] on every tick. Falls back to
  /// [DateTime.now] outside a [ClockScope] (e.g. full-screen pushes).
  static DateTime now(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ClockInherited>()?.now ?? DateTime.now();

  @override
  State<ClockScope> createState() => _ClockScopeState();
}

class _ClockScopeState extends State<ClockScope> {
  DateTime _now = DateTime.now();
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tick, (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ClockInherited(now: _now, child: widget.child);
}

class _ClockInherited extends InheritedWidget {
  const _ClockInherited({required this.now, required super.child});

  final DateTime now;

  @override
  bool updateShouldNotify(_ClockInherited oldWidget) => now != oldWidget.now;
}
