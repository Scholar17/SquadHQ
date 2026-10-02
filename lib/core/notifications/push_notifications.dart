import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env.dart';
import 'local_notifications.dart';
import 'web_platform.dart';

/// Where push notifications stand on this device.
enum PushStatus {
  /// Can't here (e.g. web without the FIREBASE_* config, or tests).
  unsupported,

  /// iPhone/iPad browser tab: add to the Home Screen and open it from
  /// there first — Apple only allows web push for Home Screen apps.
  needsHomeScreen,

  /// Never asked — needs a tap on "Turn on" (browsers require one).
  notAsked,

  /// Denied in the browser or phone settings.
  blocked,

  on,
}

/// Server pushes via Firebase Cloud Messaging, on Android and the web app.
/// Registers this device's FCM token with Supabase (`register_push_token`,
/// supabase/sql/012) so the push-dispatcher Edge Function can reach it.
/// A no-op until [init] succeeds — in tests, or on web without the
/// FIREBASE_* config in .env.
abstract final class PushNotifications {
  static bool _ready = false;
  static String? _token;
  static StreamSubscription<String>? _tokenRefresh;

  /// Where a tapped notification should go, e.g. "/wallet".
  static void Function(String route)? _onOpen;

  /// A push that arrived while the app was open on web (Android shows it as
  /// a system notification instead).
  static void Function(String title, String body, String route)? _onForeground;

  static bool get isSupported => _ready;

  static FirebaseOptions? get _webOptions {
    final apiKey = Env.optional('FIREBASE_WEB_API_KEY');
    final appId = Env.optional('FIREBASE_WEB_APP_ID');
    final senderId = Env.optional('FIREBASE_MESSAGING_SENDER_ID');
    final projectId = Env.optional('FIREBASE_PROJECT_ID');
    if (apiKey == null || appId == null || senderId == null || projectId == null) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: senderId,
      projectId: projectId,
      authDomain: Env.optional('FIREBASE_AUTH_DOMAIN'),
      storageBucket: Env.optional('FIREBASE_STORAGE_BUCKET'),
    );
  }

  static Future<void> init({
    required void Function(String route) onOpen,
    required void Function(String title, String body, String route) onForeground,
  }) async {
    _onOpen = onOpen;
    _onForeground = onForeground;
    try {
      if (kIsWeb) {
        final options = _webOptions;
        if (options == null) return;
        await Firebase.initializeApp(options: options);
      } else {
        // Android reads android/app/google-services.json.
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onMessage.listen(_showForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      _ready = true;
      // Opened the app by tapping a push while it was closed.
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (error) {
      debugPrint('Push notifications unavailable: $error');
    }
  }

  static String _route(RemoteMessage message) =>
      message.data['route'] as String? ?? '/home';

  static void _open(RemoteMessage message) => _onOpen?.call(_route(message));

  static void _showForeground(RemoteMessage message) {
    final title = message.notification?.title ?? 'Squad HQ';
    final body = message.notification?.body ?? '';
    if (kIsWeb) {
      _onForeground?.call(title, body, _route(message));
    } else {
      LocalNotifications.showUpdate(title: title, body: body, route: _route(message));
    }
  }

  /// Where notifications stand here — without asking for anything.
  static Future<PushStatus> status() async {
    if (kIsWeb && isIosWeb && !isStandaloneWebApp) return PushStatus.needsHomeScreen;
    if (!_ready) return PushStatus.unsupported;
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushStatus.on,
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PushStatus.blocked,
        AuthorizationStatus.notDetermined => PushStatus.notAsked,
      };
    } catch (_) {
      return PushStatus.unsupported;
    }
  }

  /// Whether the user has already allowed notifications — without asking.
  static Future<bool> isAllowed() async {
    if (!_ready) return false;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Asks for permission if needed, then registers this device for the
  /// signed-in profile. Returns whether notifications are on. On web, call
  /// from a tap — browsers block permission prompts that aren't.
  static Future<bool> enable() async {
    if (!_ready) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return false;
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? Env.optional('FIREBASE_WEB_VAPID_KEY') : null,
      );
      if (token == null) return false;
      await _register(token);
      _tokenRefresh ??= FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      return true;
    } catch (error) {
      debugPrint('Couldn\'t turn on push notifications: $error');
      return false;
    }
  }

  static Future<void> _register(String token) async {
    _token = token;
    await Supabase.instance.client.rpc('register_push_token', params: {
      'p_token': token,
      'p_platform': kIsWeb ? 'web' : 'android',
    });
  }

  /// Signing out: stop this device getting the old account's pushes.
  static Future<void> disable() async {
    if (!_ready) return;
    try {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await Supabase.instance.client.rpc('unregister_push_token', params: {'p_token': token});
      }
      await _tokenRefresh?.cancel();
      _tokenRefresh = null;
      _token = null;
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Couldn\'t unregister push notifications: $error');
    }
  }
}
