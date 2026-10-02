import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/env.dart';
import 'core/notifications/local_notifications.dart';
import 'core/notifications/notification_routing.dart';
import 'core/notifications/push_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Team time zones (MOTM voting deadlines, the time zone picker).
  tz_data.initializeTimeZones();
  await initDependencies();
  await Supabase.initialize(
    url: Env.require('SUPABASE_URL'),
    publishableKey: Env.require('SUPABASE_ANON_KEY'),
  );
  // Both no-op where unsupported (e.g. web without the FIREBASE_* config).
  await LocalNotifications.init(onOpen: NotificationRouting.open);
  await PushNotifications.init(
    onOpen: NotificationRouting.open,
    onForeground: NotificationRouting.showBanner,
  );
  runApp(const SquadHqApp());
}