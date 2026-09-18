import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection_container.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/domain/entities/app_user.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/onboarding_page.dart';
import 'features/match/presentation/bloc/match_bloc.dart';
import 'features/team/presentation/pages/app_shell_page.dart';
import 'features/team_membership/presentation/bloc/team_membership_bloc.dart';
import 'features/team_membership/presentation/bloc/team_membership_event.dart';
import 'features/team_membership/presentation/bloc/team_membership_state.dart';

class SquadHqApp extends StatelessWidget {
  const SquadHqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AuthBloc>()),
        // Provided above the Navigator (not inside AppShellPage) so every
        // screen shares one team list/active-team state, including ones
        // reached via Navigator.push (e.g. ProfilePage), which sit outside
        // any provider AppShellPage sets up locally.
        BlocProvider(create: (_) => sl<TeamMembershipBloc>()),
        // Same reasoning — the create-match sheet needs it too.
        BlocProvider(create: (_) => sl<MatchBloc>()),
      ],
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
        AuthAuthenticated(:final user) => _TeamGate(user: user),
        _ => const LoginPage(),
      };
}

/// A signed-in profile lands on [AppShellPage] once its team list has
/// loaded — whether or not it actually has a team yet. Home itself shows
/// an empty state with a "create or join" prompt when it doesn't; there's
/// no separate full-screen gate for that (see [DashboardPage]).
class _TeamGate extends StatefulWidget {
  const _TeamGate({required this.user});

  final AppUser user;

  @override
  State<_TeamGate> createState() => _TeamGateState();
}

class _TeamGateState extends State<_TeamGate> {
  @override
  void initState() {
    super.initState();
    context.read<TeamMembershipBloc>().add(const TeamMembershipStarted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeamMembershipBloc, TeamMembershipState>(
      // AppShellPage re-dispatches TeamMembershipStarted on mount to
      // refresh itself, which emits a transient TeamMembershipLoading
      // first. Rebuilding this gate on that would tear AppShellPage down
      // to a spinner and back, forcing a fresh instance whose initState
      // re-dispatches the same event — an infinite teardown/rebuild loop.
      // Only re-decide on real data, and only for the first load.
      buildWhen: (previous, current) => current is TeamMembershipLoaded,
      builder: (context, state) {
        if (state is! TeamMembershipLoaded) {
          return const Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }
        return AppShellPage(user: widget.user);
      },
    );
  }
}
