import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/clock/clock_scope.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/notifications/notification_routing.dart';
import '../../../../core/notifications/push_notifications.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../match/presentation/bloc/match_bloc.dart';
import '../../../match/presentation/bloc/match_event.dart';
import '../../../match/presentation/bloc/match_history_bloc.dart';
import '../../../match/presentation/bloc/match_state.dart';
import '../../../notifications/domain/entities/app_notification.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../../../notifications/presentation/notification_navigation.dart';
import '../../../squad/presentation/active_group.dart';
import '../../../squad/presentation/bloc/squad_ledger_bloc.dart';
import '../../../team_membership/domain/entities/team.dart' as membership;
import '../../../team_membership/presentation/bloc/team_membership_bloc.dart';
import '../../../team_membership/presentation/bloc/team_membership_state.dart';
import '../../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../../wallet/presentation/bloc/wallet_event.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_event.dart';
import '../match_reminders.dart';
import '../pending_actions.dart';
import '../view_role.dart';
import '../../domain/entities/team_snapshot.dart' show SquadRole;

/// Four tabs, hard stop — Home, Match, Wallet, Squad. One [TeamBloc] feeds
/// all four so the fixture, roster and role toggle stay in sync between
/// tabs. Tab state itself lives in go_router's [StatefulNavigationShell]
/// (see app_router.dart), which keeps each branch's own Navigator/state —
/// this widget just renders the bottom nav around it.
class AppShellPage extends StatelessWidget {
  const AppShellPage({super.key, required this.user, required this.navigationShell});

  final AppUser user;
  final StatefulNavigationShell navigationShell;

  static const _teamTabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.sports_soccer_rounded, label: 'Match'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
    (icon: Icons.groups_rounded, label: 'Squad'),
  ];

  /// A squad's tabs fill the same four slots (see GroupTab).
  static const _squadTabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.receipt_long_rounded, label: 'Expenses'),
    (icon: Icons.swap_horiz_rounded, label: 'Settle'),
    (icon: Icons.groups_rounded, label: 'Members'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TeamBloc>()..add(const TeamStarted()),
      child: ClockScope(
        child: _BackButtonScope(
          navigationShell: navigationShell,
          child: Scaffold(
            backgroundColor: AppColors.bg,
            body: MatchReminderSync(
              userId: user.id,
              child: _ActiveTeamSync(userId: user.id, child: navigationShell),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  border: Border(top: BorderSide(color: AppColors.text.withValues(alpha: 0.08))),
                ),
                child: Builder(
                  builder: (context) {
                    final isSquad = watchActiveGroup(context)?.isSquad ?? false;
                    final tabs = isSquad ? _squadTabs : _teamTabs;
                    final pending = PendingActions.of(context, user.id);
                    final settleAlert = isSquad && _squadSettleAlert(context, user.id);
                    return Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: _NavItem(
                              icon: tabs[i].icon,
                              label: tabs[i].label,
                              alert: switch (i) {
                                _ when isSquad => i == _walletTab && settleAlert,
                                _homeTab => pending.homeTabAlert,
                                _matchTab => pending.matchTabAlert,
                                _walletTab => pending.walletTabAlert,
                                _ => false,
                              },
                              selected: navigationShell.currentIndex == i,
                              onTap: () => navigationShell.goBranch(
                                i,
                                initialLocation: i == navigationShell.currentIndex,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A dot on Settle while a payment waits for you to confirm it, or you
  /// owe someone.
  static bool _squadSettleAlert(BuildContext context, String userId) {
    final ledger = context.watch<SquadLedgerBloc>().state.ledger;
    if (ledger == null) return false;
    return ledger.awaitingConfirmationBy(userId).isNotEmpty || ledger.balanceOf(userId) < 0;
  }

  static const _homeTab = 0;
  static const _matchTab = 1;
  static const _walletTab = 2;
}

/// Keeps the app-root [MatchBloc], [WalletBloc] and [MatchHistoryBloc]
/// pointed at the active team. Loads once on mount — the team list has
/// already settled by the time the shell is built (see app_router.dart's
/// _TeamGate), so a change-only listener alone would never fire for it —
/// then follows every later team switch. Also refreshes the wallet and
/// history whenever a match is created, edited or cancelled, and all three
/// quietly every few minutes and when the app comes back to the
/// foreground — so a match that kicks off or finishes moves on (upcoming →
/// history → Home's recaps) without a restart.
class _ActiveTeamSync extends StatefulWidget {
  const _ActiveTeamSync({required this.userId, required this.child});

  final String userId;
  final Widget child;

  @override
  State<_ActiveTeamSync> createState() => _ActiveTeamSyncState();
}

class _ActiveTeamSyncState extends State<_ActiveTeamSync> with WidgetsBindingObserver {
  static const _refreshEvery = Duration(minutes: 5);

  late final Timer _refreshTimer;

  static String? _activeTeamId(TeamMembershipState state) {
    final settled = switch (state) {
      TeamMembershipSubmitting(:final previous) => previous,
      TeamMembershipFailure(:final previous) => previous,
      _ => state,
    };
    if (settled is! TeamMembershipLoaded) return null;
    for (final team in settled.teams) {
      if (team.isActive) return team.id;
    }
    return null;
  }

  static String? _activeTimezone(TeamMembershipState state) {
    final settled = switch (state) {
      TeamMembershipSubmitting(:final previous) => previous,
      TeamMembershipFailure(:final previous) => previous,
      _ => state,
    };
    if (settled is! TeamMembershipLoaded) return null;
    for (final team in settled.teams) {
      if (team.isActive) return team.timezone;
    }
    return null;
  }

  /// Read once — [dispose] can't look it up.
  late final NotificationBloc _notifications = context.read<NotificationBloc>();

  @override
  void initState() {
    super.initState();
    _select(_activeTeamId(context.read<TeamMembershipBloc>().state));
    _notifications.add(const NotificationsStarted());
    NotificationRouting.setNotificationOpener(_openNotification);
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _refresh());
    WidgetsBinding.instance.addObserver(this);
    _turnOnPush();
  }

  /// Registers this device for push. Android asks for permission (once);
  /// web only registers if it's already allowed — browsers need a tap to
  /// ask, which is the Profile page's "Turn on".
  Future<void> _turnOnPush() async {
    if (!kIsWeb || await PushNotifications.isAllowed()) {
      await PushNotifications.enable();
    }
  }

  @override
  void dispose() {
    // The shell goes away on sign-out.
    NotificationRouting.setNotificationOpener(null);
    _notifications.add(const NotificationsStopped(clear: true));
    _refreshTimer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _refresh();
        // Reloads too, catching anything sent while away.
        _notifications.add(const NotificationsStarted());
      case AppLifecycleState.hidden:
        // No live connection held in the background.
        _notifications.add(const NotificationsStopped());
      default:
        break;
    }
  }

  /// A tapped push (see NotificationRouting): opens it as the notification
  /// list would — loading the list first if it isn't in yet.
  Future<void> _openNotification(String id) async {
    AppNotification? find() =>
        _notifications.state.items.where((item) => item.id == id).firstOrNull;
    var notification = find();
    if (notification == null) {
      final done = Completer<void>();
      _notifications.add(NotificationsRefreshRequested(done: done));
      await done.future;
      notification = find();
    }
    if (!mounted) return;
    if (notification == null) {
      context.go(AppRoutes.home);
      return;
    }
    await openNotification(
      context,
      notification,
      userId: widget.userId,
      adminViewIsManager:
          viewRoleFor(membership.TeamRole.admin, context.read<TeamBloc>().state) ==
              SquadRole.manager,
    );
  }

  /// Points the football blocs at a team, or the squad bloc at a squad —
  /// each gets null for the other kind, so nothing loads that isn't shown.
  void _select(String? teamId) {
    final group = activeGroupOf(context.read<TeamMembershipBloc>().state);
    final squadId = group != null && group.id == teamId && group.isSquad ? teamId : null;
    final teamOnlyId = squadId == null ? teamId : null;
    context.read<MatchBloc>().add(MatchTeamSelected(teamOnlyId));
    context.read<WalletBloc>().add(WalletTeamSelected(teamOnlyId));
    context.read<MatchHistoryBloc>().add(MatchHistoryTeamSelected(teamOnlyId));
    context.read<SquadLedgerBloc>().add(SquadSelected(squadId));
  }

  void _refresh() {
    context.read<SquadLedgerBloc>().add(const SquadRefreshRequested());
    context.read<MatchBloc>().add(const MatchRefreshRequested());
    context.read<WalletBloc>().add(const WalletRefreshRequested());
    context.read<MatchHistoryBloc>().add(const MatchHistoryStarted());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TeamMembershipBloc, TeamMembershipState>(
          listenWhen: (previous, current) => _activeTeamId(previous) != _activeTeamId(current),
          listener: (context, state) => _select(_activeTeamId(state)),
        ),
        BlocListener<TeamMembershipBloc, TeamMembershipState>(
          listenWhen: (previous, current) =>
              _activeTeamId(previous) == _activeTeamId(current) &&
              _activeTimezone(previous) != _activeTimezone(current),
          listener: (context, state) =>
              context.read<MatchHistoryBloc>().add(const MatchHistoryStarted()),
        ),
        BlocListener<MatchBloc, MatchState>(
          listenWhen: (previous, current) => previous is MatchSubmitting && current is MatchLoaded,
          listener: (context, state) {
            context.read<WalletBloc>().add(const WalletRefreshRequested());
            context.read<MatchHistoryBloc>().add(const MatchHistoryStarted());
          },
        ),
      ],
      child: widget.child,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shows a "!" badge — something on this tab needs the user's action.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.45);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 22, color: color),
              if (alert)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.neutral100, width: 1.5),
                    ),
                    child: Text(
                      '!',
                      semanticsLabel: 'Action needed',
                      style: AppTextStyles.body(
                        size: 9,
                        weight: FontWeight.w900,
                        color: AppColors.neutral100,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Android back button on the tabs: from Match, Wallet or Squad it goes to
/// Home; on Home, the first press shows "Press back again to exit" and a
/// second within [_exitWindow] closes the app. Screens pushed on top
/// (Profile, history…) aren't affected — they're above the shell and just
/// close. On web the browser's back button keeps its usual behaviour.
class _BackButtonScope extends StatefulWidget {
  const _BackButtonScope({required this.navigationShell, required this.child});

  final StatefulNavigationShell navigationShell;
  final Widget child;

  @override
  State<_BackButtonScope> createState() => _BackButtonScopeState();
}

class _BackButtonScopeState extends State<_BackButtonScope> {
  static const _exitWindow = Duration(seconds: 2);

  DateTime? _lastBackOnHome;

  void _onBack() {
    final shell = widget.navigationShell;
    if (shell.currentIndex != 0) {
      shell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    final last = _lastBackOnHome;
    if (last != null && now.difference(last) < _exitWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBackOnHome = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Press back again to exit'), duration: _exitWindow),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return widget.child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: widget.child,
    );
  }
}
