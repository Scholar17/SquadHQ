import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// Where tapped notifications go, and the in-app banner for pushes that
/// arrive while the web app is open.
///
/// A push's route is either a tab (`/match`, `/wallet`) or its entry in the
/// notification list, `/notifications/<id>` — which opens the match (or
/// Wallet) it's about, via the opener the signed-in shell registers.
/// Notifications can arrive before the app is ready (the tap that launched
/// it, or before sign-in finishes), so a route waits until both the router
/// is [attach]ed and the shell has registered its opener.
///
/// A share link (`/open/<token>`, or `/s/<token>` if it reaches the app)
/// waits the same way, for the shell's share opener.
abstract final class NotificationRouting {
  static GoRouter? _router;
  static Future<void> Function(String notificationId)? _openNotification;
  static Future<void> Function(String token)? _openShare;
  static String? _pending;

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static const _notificationPrefix = '/notifications/';

  /// The notification id in a `/notifications/<id>` route, else null.
  static String? notificationIdIn(String route) {
    if (!route.startsWith(_notificationPrefix)) return null;
    final id = route.substring(_notificationPrefix.length);
    return id.isEmpty || id.contains('/') ? null : id;
  }

  static const _sharePrefixes = ['/open/', '/s/'];

  /// The token in a share link's route, else null.
  static String? shareTokenIn(String route) {
    for (final prefix in _sharePrefixes) {
      if (!route.startsWith(prefix)) continue;
      final token = route.substring(prefix.length);
      return token.isEmpty || token.contains('/') ? null : token;
    }
    return null;
  }

  static void attach(GoRouter router) {
    _router = router;
    _flush();
  }

  /// Set by the signed-in shell (null when it goes away, e.g. on sign-out):
  /// opens one notification from the list.
  static void setNotificationOpener(Future<void> Function(String notificationId)? opener) {
    _openNotification = opener;
    _flush();
  }

  /// Set by the signed-in shell, like [setNotificationOpener]: opens what
  /// a share link is about.
  static void setShareOpener(Future<void> Function(String token)? opener) {
    _openShare = opener;
    _flush();
  }

  static void open(String route) {
    _pending = route;
    _flush();
  }

  /// Opens the pending route once ready — after the current frame, since
  /// this can be reached mid-navigation (e.g. from a router redirect).
  static void _flush() {
    final pending = _pending;
    if (pending == null || !_canOpen(pending)) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        final route = _pending;
        // Re-checked: sign-out may have happened in between.
        if (route == null || !_canOpen(route)) return;
        _pending = null;
        final id = notificationIdIn(route);
        final token = shareTokenIn(route);
        if (id != null) {
          _openNotification!(id);
        } else if (token != null) {
          _openShare!(token);
        } else {
          _router!.go(route);
        }
      })
      ..scheduleFrame();
  }

  /// A notification needs only its opener, a share link its own; a tab
  /// route the router, once signed in.
  static bool _canOpen(String route) {
    if (notificationIdIn(route) != null) return _openNotification != null;
    if (shareTokenIn(route) != null) return _openShare != null;
    return _openNotification != null && _router != null;
  }

  static void showBanner(String title, String body, String route) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body.isEmpty ? title : '$title — $body'),
          action: SnackBarAction(label: 'Open', onPressed: () => open(route)),
          duration: const Duration(seconds: 6),
        ),
      );
  }
}
