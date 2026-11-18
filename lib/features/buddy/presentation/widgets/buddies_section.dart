import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../squad/domain/entities/squad_ledger.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../cubit/buddy_cubit.dart';

/// The Settle tab's "BUDDIES": each squad-mate you share buddy expenses
/// with and where you stand. Nothing shows until you have one.
class BuddiesSection extends StatefulWidget {
  const BuddiesSection({super.key, required this.teamId, required this.me, required this.ledger});

  final String teamId;
  final String me;
  final SquadLedger ledger;

  @override
  State<BuddiesSection> createState() => _BuddiesSectionState();
}

class _BuddiesSectionState extends State<BuddiesSection> {
  final _cubit = sl<BuddyCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.load(widget.teamId);
  }

  @override
  void didUpdateWidget(BuddiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new squad, or the squad reloaded (pulled to refresh, a change).
    if (oldWidget.teamId != widget.teamId || oldWidget.ledger != widget.ledger) {
      _cubit.load(widget.teamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BuddyCubit, BuddyState>(
      bloc: _cubit,
      builder: (context, state) {
        final buddies = state.teamId == widget.teamId ? state.ledger : null;
        if (buddies == null || buddies.buddies.isEmpty) return const SizedBox.shrink();
        final currency = widget.ledger.currency;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            SquadSectionLabel('BUDDIES', trailing: '${buddies.buddies.length}'),
            const SizedBox(height: 8),
            for (final id in buddies.buddies) ...[
              Builder(
                builder: (context) {
                  final balance = buddies.balanceWith(id);
                  final waiting = buddies.awaitingMeFrom(id).length;
                  return SquadCard(
                    onTap: () => context.push(AppRoutes.buddy(id)),
                    child: Row(
                      children: [
                        SquadAvatar(
                          initial: widget.ledger.member(id)?.initial ?? '?',
                          size: 34,
                          photoUrl: widget.ledger.member(id)?.avatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ledger.nameOf(id),
                                style: AppTextStyles.body(size: 14.5, weight: FontWeight.w700),
                              ),
                              Text(
                                [
                                  switch (balance) {
                                    < 0 => 'You owe ${formatMoney(-balance, currency)}',
                                    > 0 => 'Owes you ${formatMoney(balance, currency)}',
                                    _ => 'All square',
                                  },
                                  if (waiting > 0) '$waiting to confirm',
                                ].join(' · '),
                                style: AppTextStyles.body(
                                  size: 12.5,
                                  color: switch (balance) {
                                    < 0 => oweColor,
                                    > 0 => owedColor,
                                    _ => squadMuted,
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: squadMuted),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
