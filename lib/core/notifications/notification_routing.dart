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
abstract final class NotificationRouting {
  static GoRouter? _router;
  static Future<void> Function(String notificationId)? _openNotification;
  static String? _pending;

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static const _notificationPrefix = '/notifications/';

  /// The notification id in a `/notifications/<id>` route, else null.
  static String? notificationIdIn(String route) {
    if (!route.startsWith(_notificationPrefix)) return null;
    final id = route.substring(_notificationPrefix.length);
    return id.isEmpty || id.contains('/') ? null : id;
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

  static void open(String route) {
    _pending = route;
    _flush();
  }

  /// Opens the pending route once ready — after the current frame, since
  /// this can be reached mid-navigation (e.g. from a router redirect).
  static void _flush() {
    final pending = _pending;
    if (pending == null || _openNotification == null) return;
    // A tab route needs the router; a notification only the opener.
    if (notificationIdIn(pending) == null && _router == null) return;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        final route = _pending;
        // Re-checked: sign-out may have happened in between.
        if (route == null || _openNotification == null) return;
        _pending = null;
        final id = notificationIdIn(route);
        if (id != null) {
          _openNotification!(id);
        } else {
          _router!.go(route);
        }
      })
      ..scheduleFrame();
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
