import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/match/presentation/pages/match_history_page.dart';
import '../../features/match/presentation/pages/match_list_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/squad/presentation/pages/expense_detail_page.dart';
import '../../features/squad/presentation/pages/expenses_page.dart';
import '../../features/squad/presentation/pages/settle_page.dart';
import '../../features/squad/presentation/pages/squad_home_page.dart';
import '../../features/squad/presentation/pages/squad_members_page.dart';
import '../../features/team/domain/entities/team_snapshot.dart';
import '../../features/team/presentation/pages/app_shell_page.dart';
import '../../features/team/presentation/pages/dashboard_page.dart';
import '../../features/team/presentation/pages/match_page.dart';
import '../../features/team/presentation/pages/player_card_page.dart';
import '../../features/team/presentation/pages/squad_page.dart';
import '../../features/team/presentation/pages/wallet_page.dart';
import '../../features/team/presentation/widgets/group_tab.dart';
import '../../features/team_membership/domain/entities/team.dart';
import '../../features/team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../features/team_membership/presentation/bloc/team_membership_event.dart';
import '../../features/team_membership/presentation/bloc/team_membership_state.dart';
import '../../features/team_membership/presentation/pages/team_membership_page.dart';
import '../../features/team_membership/presentation/pages/team_roster_page.dart';
import '../../features/wallet/presentation/pages/wallet_bills_page.dart';
import '../notifications/notification_routing.dart';
import '../theme/app_colors.dart';

/// Route paths, named so push sites don't hand-type strings.
abstract final class AppRoutes {
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const match = '/match';
  static const wallet = '/wallet';
  static const squad = '/squad';
  static const profile = '/profile';
  static const team = '/team';
  static const teamRoster = '/team/roster';
  static const teamPlayer = '/team/player';
  static const matches = '/matches';
  static const matchHistory = '/match-history';
  static const upcomingMatch = '/match-detail';
  static const notifications = '/notifications';

  /// A squad expense's detail screen.
  static String expenseDetail(String expenseId) => '/expense/$expenseId';
  static const walletBills = '/wallet-bills';
}

/// [WalletBillsPage]'s args, bundled for `extra:`.
class WalletBillsArgs {
  const WalletBillsArgs({required this.userId, required this.isManager});

  final String userId;
  final bool isManager;
}

/// [MatchListPage]'s constructor args, bundled for `extra:`.
class MatchListArgs {
  const MatchListArgs({
    required this.activeTeamId,
    required this.teamName,
    required this.userId,
    required this.canCreateMatch,
  });

  final String activeTeamId;
  final String teamName;
  final String userId;

  /// Whether the viewer is an admin in the Manager view — also passed on
  /// to each match's detail screen.
  final bool canCreateMatch;
}

/// [NotificationsPage]'s args, bundled for `extra:`. A full-screen push
/// outside the tab shell, like [UpcomingMatchArgs].
class NotificationsArgs {
  const NotificationsArgs({required this.userId, required this.adminViewIsManager});

  final String userId;

  /// Whether an admin is in the Manager view (Home's header toggle) — so a
  /// notification opens its match the way the tabs show it.
  final bool adminViewIsManager;
}

/// [UpcomingMatchPage]'s args, bundled for `extra:`. It's a full-screen
/// push outside the tab shell, so the Manager/Player view is passed in
/// rather than read from the shell's TeamBloc.
class UpcomingMatchArgs {
  const UpcomingMatchArgs({
    required this.matchId,
    required this.teamName,
    required this.userId,
    required this.isManager,
  });

  final String matchId;
  final String teamName;
  final String userId;
  final bool isManager;
}

/// [AuthLoading] and [AuthFailure] both wrap a settled state (the screen to
/// keep showing underneath); unwrap down to it. Bloc transitions never nest
/// these, so one pass is enough. Same invariant _AuthGate used to rely on.
AuthState _settledAuthState(AuthState state) => switch (state) {
      AuthLoading(:final previous) => previous,
      AuthFailure(:final previous) => previous,
      _ => state,
    };

AppUser? _authedUser(BuildContext context) =>
    switch (_settledAuthState(context.read<AuthBloc>().state)) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };

String? _authRedirect(GoRouterState state, AuthBloc authBloc) {
  final settled = _settledAuthState(authBloc.state);

  // A web push's link (see supabase/sql/023_push_opens_notification.sql):
  // NotificationRouting opens it once signed in, from wherever this lands.
  if (NotificationRouting.notificationIdIn(state.uri.path) != null) {
    NotificationRouting.open(state.uri.path);
    return switch (settled) {
      AuthNeedsOnboarding() => AppRoutes.onboarding,
      AuthAuthenticated() => AppRoutes.home,
      _ => AppRoutes.login,
    };
  }

  final onLogin = state.matchedLocation == AppRoutes.login;
  final onOnboarding = state.matchedLocation == AppRoutes.onboarding;

  if (settled is AuthNeedsOnboarding) {
    return onOnboarding ? null : AppRoutes.onboarding;
  }
  if (settled is AuthAuthenticated) {
    return (onLogin || onOnboarding) ? AppRoutes.home : null;
  }
  return onLogin ? null : AppRoutes.login;
}

GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) => _authRedirect(state, authBloc),
    errorBuilder: (context, state) => const _SettlingPage(),
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) {
          final settled = _settledAuthState(context.read<AuthBloc>().state);
          if (settled case AuthNeedsOnboarding(:final user)) {
            return OnboardingPage(user: user);
          }
          return const _SettlingPage();
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          final user = _authedUser(context);
          if (user == null) return const _SettlingPage();
          return _TeamGate(user: user, navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) {
                  final user = _authedUser(context);
                  return user == null
                      ? const _SettlingPage()
                      : GroupTab(team: DashboardPage(user: user), squad: SquadHomePage(user: user));
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.match,
                builder: (context, state) {
                  final user = _authedUser(context);
                  return user == null
                      ? const _SettlingPage()
                      : GroupTab(team: MatchPage(user: user), squad: ExpensesPage(user: user));
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallet,
                builder: (context, state) {
                  final user = _authedUser(context);
                  return user == null
                      ? const _SettlingPage()
                      : GroupTab(team: WalletPage(user: user), squad: SettlePage(user: user));
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.squad,
                builder: (context, state) {
                  final user = _authedUser(context);
                  return user == null
                      ? const _SettlingPage()
                      : GroupTab(team: SquadPage(user: user), squad: SquadMembersPage(user: user));
                },
              ),
            ],
          ),
        ],
      ),
      // Full-screen pushes — top-level (not nested under the shell
      // branches) so they cover the bottom nav, matching how
      // Navigator.push used to behave before this migration.
      GoRoute(
        path: AppRoutes.profile,
        // `extra` doesn't survive a hot reload or state restoration, so fall
        // back to the signed-in user rather than crash.
        builder: (context, state) {
          final user = state.extra as AppUser? ?? _authedUser(context);
          return user == null ? const _SettlingPage() : ProfilePage(user: user);
        },
      ),
      GoRoute(
        path: AppRoutes.team,
        builder: (context, state) => const TeamMembershipPage(),
      ),
      GoRoute(
        path: AppRoutes.teamRoster,
        builder: (context, state) => TeamRosterPage(team: state.extra! as Team),
      ),
      GoRoute(
        path: AppRoutes.teamPlayer,
        builder: (context, state) => PlayerCardPage(member: state.extra! as SquadMember),
      ),
      GoRoute(
        path: AppRoutes.matchHistory,
        builder: (context, state) => MatchHistoryPage(args: state.extra! as MatchHistoryArgs),
      ),
      GoRoute(
        path: AppRoutes.matches,
        builder: (context, state) {
          final args = state.extra! as MatchListArgs;
          return MatchListPage(
            activeTeamId: args.activeTeamId,
            teamName: args.teamName,
            userId: args.userId,
            canCreateMatch: args.canCreateMatch,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.walletBills,
        builder: (context, state) {
          final args = state.extra! as WalletBillsArgs;
          return WalletBillsPage(userId: args.userId, isManager: args.isManager);
        },
      ),
      GoRoute(
        path: AppRoutes.upcomingMatch,
        builder: (context, state) =>
            UpcomingMatchPage(args: state.extra! as UpcomingMatchArgs),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) =>
            NotificationsPage(args: state.extra! as NotificationsArgs),
      ),
      GoRoute(
        path: '/expense/:id',
        builder: (context, state) {
          final user = _authedUser(context);
          return user == null
              ? const _SettlingPage()
              : ExpenseDetailPage(expenseId: state.pathParameters['id']!, user: user);
        },
      ),
      // Never shown: _authRedirect hands these push links off. Declared so
      // the location matches a route rather than erroring.
      GoRoute(
        path: '${AppRoutes.notifications}/:id',
        builder: (context, state) => const _SettlingPage(),
      ),
    ],
  );
}

/// A signed-in profile lands on [AppShellPage] once its team list has
/// loaded — whether or not it actually has a team yet. Home itself shows
/// an empty state with a "create or join" prompt when it doesn't; there's
/// no separate full-screen gate for that (see DashboardPage).
class _TeamGate extends StatefulWidget {
  const _TeamGate({required this.user, required this.navigationShell});

  final AppUser user;
  final StatefulNavigationShell navigationShell;

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
          return const _SettlingPage();
        }
        return AppShellPage(user: widget.user, navigationShell: widget.navigationShell);
      },
    );
  }
}

/// Shown for a frame or two while auth/onboarding state is mid-transition
/// and the router is about to redirect somewhere settled.
class _SettlingPage extends StatelessWidget {
  const _SettlingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
    );
  }
}

/// Bridges an [AuthBloc]'s stream into a [Listenable] go_router can use as
/// `refreshListenable`, so route `redirect`s re-run whenever auth state
/// changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
