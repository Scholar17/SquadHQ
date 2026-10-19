import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'browser_history.dart';

/// Makes the browser's back button behave like Android's on web.
///
/// The router runs with `routerNeglect` on web, so tab switches and pushed
/// screens replace the current history entry instead of piling up new
/// ones. On top of that this keeps a few "guard" entries: each browser back
/// pops one (a popstate, which arrives as a pushed route), and rather than
/// letting go_router jump to that stale entry, the press runs through the
/// router's normal back handling — closing a sheet or screen, or reaching
/// the tabs' PopScope (Home, then "press back again to exit").
///
/// Guard entries are only added straight after a tap or key press. Chrome
/// marks history entries a page adds without one as skippable, and once
/// every entry behind the current one is, Android's back closes the app
/// without the page ever seeing it — so they're never re-added after a
/// back press, only topped up on the next touch.
///
/// The web can't close itself: on Home, [release] takes the guard entries
/// off so the next back has nothing to go back to and Android closes the
/// app (in a desktop tab, the browser goes back to the previous site).
class WebBackGuard with WidgetsBindingObserver {
  WebBackGuard._(this._router, this._fallbackLocation, this._historyGo);

  final GoRouter _router;
  final String _fallbackLocation;
  final void Function(int delta) _historyGo;

  /// Guard entries kept above the app's own — enough back presses in a row
  /// (player card → past match → history → tab → Home → exit) between taps.
  static const bufferSize = 5;

  static WebBackGuard? _installed;

  /// Guard entries currently above the app's own.
  int _depth = 0;

  /// Popstates this guard caused itself ([release]), not the back button.
  int _ownPopstates = 0;

  /// Installs the guard for [router] — web only. Must run before the
  /// router's [Router] widget mounts, so this observer is asked about
  /// popstates before go_router's own one. A back press with nothing left
  /// to close goes to [fallbackLocation].
  /// Returns the guard (null when not [enabled]) so tests can remove it.
  static WebBackGuard? install(
    GoRouter router, {
    required String fallbackLocation,
    bool enabled = kIsWeb,
    void Function(int delta) historyGo = browserHistoryGo,
  }) {
    if (!enabled) return null;
    final guard = WebBackGuard._(router, fallbackLocation, historyGo);
    WidgetsBinding.instance.addObserver(guard);
    GestureBinding.instance.pointerRouter.addGlobalRoute(guard._onPointer);
    HardwareKeyboard.instance.addHandler(guard._onKey);
    _installed = guard;
    return guard;
  }

  /// Takes the guard off — for tests.
  void remove() {
    WidgetsBinding.instance.removeObserver(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (_installed == this) _installed = null;
  }

  /// Home's first back: takes the guard entries off, so the next back
  /// leaves the app. A tap before then puts them back. No-op off the web.
  static void release() => _installed?._release();

  // Touch counts as user activation on its pointerup, not pointerdown.
  void _onPointer(PointerEvent event) {
    if (event is PointerUpEvent) _topUp();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) _topUp();
    return false;
  }

  void _topUp() {
    if (_depth >= bufferSize) return;
    final current = _router.routeInformationProvider.value;
    // Not reported to the browser yet (its state is still go_router's
    // in-memory form, not the encoded map): the next tap tops up.
    if (current.state is! Map) return;
    while (_depth < bufferSize) {
      SystemNavigator.routeInformationUpdated(uri: current.uri, state: current.state);
      _depth++;
    }
  }

  void _release() {
    if (_depth == 0) return;
    _ownPopstates++;
    _historyGo(-_depth);
    _depth = 0;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    // Every history entry is replaced in place, so a popstate is either
    // [release] or the back button taking a guard entry off.
    if (_ownPopstates > 0) {
      _ownPopstates--;
      // The entry landed on still has the location it had when the guard
      // went up: point it (and the address bar) at where the app is now.
      final current = _router.routeInformationProvider.value;
      SystemNavigator.routeInformationUpdated(uri: current.uri, state: current.state, replace: true);
      return true;
    }
    if (_depth > 0) _depth--;
    final handled = await _router.routerDelegate.popRoute();
    if (!handled) _router.go(_fallbackLocation);
    return true;
  }
}
