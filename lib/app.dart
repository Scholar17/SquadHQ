import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:go_router/go_router.dart';

import 'core/di/injection_container.dart';
import 'core/notifications/notification_routing.dart';
import 'core/routing/app_router.dart';
import 'core/splash/kickoff_splash.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/widgets/responsive_frame.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/match/presentation/bloc/match_bloc.dart';
import 'features/match/presentation/bloc/match_history_bloc.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'features/squad/presentation/bloc/squad_ledger_bloc.dart';
import 'features/team_membership/presentation/bloc/team_membership_bloc.dart';
import 'features/team_membership/presentation/bloc/team_membership_state.dart';
import 'features/wallet/presentation/bloc/wallet_bloc.dart';

class SquadHqApp extends StatefulWidget {
  const SquadHqApp({super.key});

  @override
  State<SquadHqApp> createState() => _SquadHqAppState();
}

class _SquadHqAppState extends State<SquadHqApp> with WidgetsBindingObserver {
  final authBloc = sl<AuthBloc>();
  final _theme = sl<ThemeController>();

  // Created once (not per build) so tapped notifications have a stable
  // router to navigate with.
  late final GoRouter _router = createAppRouter(authBloc);

  @override
  void initState() {
    super.initState();
    NotificationRouting.attach(_router);
    WidgetsBinding.instance.addObserver(this);
    _theme.addListener(_applyTheme);
    // First frame: just pick the palette — nothing's built to repaint yet.
    _applyTheme(repaint: false);
  }

  @override
  void dispose() {
    _theme.removeListener(_applyTheme);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// "System" follows the phone as it switches.
  @override
  void didChangePlatformBrightness() => _applyTheme();

  /// Points [AppColors] at the chosen palette and repaints every screen
  /// with it — including widgets that wouldn't rebuild on their own
  /// (const ones read the colours in build, not via an inherited theme).
  void _applyTheme({bool repaint = true}) {
    final brightness = switch (_theme.value) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    final palette = brightness == Brightness.dark ? AppPalette.dark : AppPalette.light;
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
    if (identical(palette, AppColors.palette)) return;
    AppColors.palette = palette;
    if (!repaint || !mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
    setState(() {});
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
        theme: AppColors.isDark ? AppTheme.dark : AppTheme.light,
        routerConfig: _router,
        scaffoldMessengerKey: NotificationRouting.messengerKey,
        // Tablets and desktop web: one readable column, not edge to edge.
        // The opening splash plays over everything until the app has loaded.
        builder: (context, child) => BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) => BlocBuilder<TeamMembershipBloc, TeamMembershipState>(
            builder: (context, teams) => KickoffSplash(
              loaded: startupLoaded(auth, teams),
              child: ResponsiveFrame(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}
