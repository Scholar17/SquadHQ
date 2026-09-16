import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/onboarding_page.dart';
import 'features/team/presentation/pages/app_shell_page.dart';

class SquadHqApp extends StatelessWidget {
  const SquadHqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: MaterialApp(
        title: 'Squad HQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AuthGate(),
        // The Facebook OAuth redirect (squadhq://login-callback?code=...)
        // arrives as a platform route push; Supabase's own deep-link
        // listener consumes the code via authStateChanges, so this just
        // needs to not crash the Navigator — land back on the auth gate.
        onUnknownRoute: (_) =>
            MaterialPageRoute(builder: (_) => const _AuthGate()),
      ),
    );
  }
}

/// Switches between login, onboarding and the app shell based on
/// [AuthState] — the single source of truth for "where does the user land".
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => _pageFor(_settle(state)),
    );
  }

  /// [AuthLoading] and [AuthFailure] both wrap a settled state (the screen
  /// to keep showing underneath); unwrap down to it. Bloc transitions never
  /// nest these, so one pass is enough.
  AuthState _settle(AuthState state) => switch (state) {
        AuthLoading(:final previous) => previous,
        AuthFailure(:final previous) => previous,
        _ => state,
      };

  Widget _pageFor(AuthState state) => switch (state) {
        AuthNeedsOnboarding(:final user) => OnboardingPage(user: user),
        AuthAuthenticated(:final user) => AppShellPage(user: user),
        _ => const LoginPage(),
      };
}
