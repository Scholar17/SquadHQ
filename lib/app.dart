import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import 'core/di/injection_container.dart';
import 'core/notifications/notification_routing.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/match/presentation/bloc/match_bloc.dart';
import 'features/match/presentation/bloc/match_history_bloc.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/squad/presentation/bloc/squad_ledger_bloc.dart';
import 'features/team_membership/presentation/bloc/team_membership_bloc.dart';
import 'features/wallet/presentation/bloc/wallet_bloc.dart';

class SquadHqApp extends StatefulWidget {
  const SquadHqApp({super.key});

  @override
  State<SquadHqApp> createState() => _SquadHqAppState();
}

class _SquadHqAppState extends State<SquadHqApp> {
  final authBloc = sl<AuthBloc>();

  // Created once (not per build) so tapped notifications have a stable
  // router to navigate with.
  late final GoRouter _router = createAppRouter(authBloc);

  @override
  void initState() {
    super.initState();
    NotificationRouting.attach(_router);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        // Provided above the router (not inside AppShellPage) so every
        // screen shares one team list/active-team state, including ones
        // reached via context.push (e.g. ProfilePage), which sit outside
        // any provider AppShellPage sets up locally.
        BlocProvider(create: (_) => sl<TeamMembershipBloc>()),
        // Same reasoning — the create-match sheet needs it too.
        BlocProvider(create: (_) => sl<MatchBloc>()),
        // And again — bill and pay sheets open as their own routes.
        BlocProvider(create: (_) => sl<WalletBloc>()),
        // Home's recaps, the tab badges and the history pages share it.
        BlocProvider(create: (_) => sl<MatchHistoryBloc>()),
        // Home's bell count and the notification list.
        BlocProvider(create: (_) => sl<NotificationBloc>()),
        // A squad's four tabs and its expense, pay and confirm sheets.
        BlocProvider(create: (_) => sl<SquadLedgerBloc>()),
      ],
      child: MaterialApp.router(
        title: 'Squad HQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
        scaffoldMessengerKey: NotificationRouting.messengerKey,
      ),
    );
  }
}