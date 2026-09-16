import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_event.dart';
import 'dashboard_page.dart';
import 'match_page.dart';
import 'squad_page.dart';
import 'wallet_page.dart';

/// Four tabs, hard stop — Home, Match, Wallet, Squad. One [TeamBloc] feeds
/// all four so the fixture, roster and role toggle stay in sync between
/// tabs.
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.user});

  final AppUser user;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _index = 0;

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.sports_soccer_rounded, label: 'Match'),
    (icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
    (icon: Icons.groups_rounded, label: 'Squad'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<TeamBloc>()..add(const TeamStarted()),
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(
          index: _index,
          children: [
            DashboardPage(user: widget.user),
            const MatchPage(),
            const WalletPage(),
            SquadPage(user: widget.user),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              border: Border(
                top: BorderSide(color: AppColors.text.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _tabs[i].icon,
                      label: _tabs[i].label,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.text.withValues(alpha: 0.45);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
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
