import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Makes the browser's back button behave like Android's on web.
///
/// The router runs with `routerNeglect` on web, so tab switches and pushed
/// screens replace the current history entry instead of piling up new
/// ones. On top of that this keeps one extra "guard" entry: the browser's
/// back pops it (a popstate, which arrives as a pushed route), and rather
/// than letting go_router jump to that stale entry, the guard is put back
/// and the press runs through the router's normal back handling — closing
/// a sheet or screen, or reaching the tabs' PopScope (Home, then "press
/// back again to exit"). Exiting is [SystemNavigator.pop], which on web
/// unwinds Flutter's entries and leaves the app.
class WebBackGuard with WidgetsBindingObserver {
  WebBackGuard._(this._router);

  final GoRouter _router;

  /// Installs the guard for [router] — web only. Must run before the
  /// router's [Router] widget mounts, so this observer is asked about
  /// popstates before go_router's own one.
  /// Returns the guard (null when not [enabled]) so tests can remove it.
  static WebBackGuard? install(GoRouter router, {bool enabled = kIsWeb}) {
    if (!enabled) return null;
    final guard = WebBackGuard._(router);
    WidgetsBinding.instance.addObserver(guard);
    // After the router has reported its first location.
    WidgetsBinding.instance.addPostFrameCallback((_) => Timer.run(guard._pushGuardEntry));
    return guard;
  }

  void _pushGuardEntry() {
    final current = _router.routeInformationProvider.value;
    // Not reported to the browser yet (its state is still go_router's
    // in-memory form, not the encoded map): try again after the next frame.
    if (current.state is! Map) {
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => Timer.run(_pushGuardEntry))
        ..scheduleFrame();
      return;
    }
    SystemNavigator.routeInformationUpdated(uri: current.uri, state: current.state);
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    // Every history entry is replaced in place, so a popstate can only be
    // the back button taking the guard off.
    _pushGuardEntry();
    final handled = await _router.routerDelegate.popRoute();
    if (!handled) await SystemNavigator.pop();
    return true;
  }
}
