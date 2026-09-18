import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/di/injection_container.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  await Supabase.initialize(
    url: Env.require('SUPABASE_URL'),
    publishableKey: Env.require('SUPABASE_ANON_KEY'),
  );
  runApp(const SquadHqApp());
}