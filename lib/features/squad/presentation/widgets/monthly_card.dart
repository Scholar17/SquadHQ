import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/recurring_expense.dart';
import '../../domain/entities/squad_ledger.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'expense_sheet.dart';
import 'remind_button.dart';
import 'squad_widgets.dart';

/// A monthly expense: what it costs, when it's charged next, who pays the
/// provider and your share. Admins, whoever set it up and its payer can tap
/// to edit, pause or stop it.
class MonthlyCard extends StatelessWidget {
  const MonthlyCard({
    super.key,
    required this.recurring,
    required this.ledger,
    required this.me,
    required this.teamId,
  });

  final RecurringExpense recurring;
  final SquadLedger ledger;
  final String me;
  final String teamId;

  static String _day(int day) => day == RecurringExpense.lastDay
      ? 'the last day'
      : 'the $day${switch (day) {
          1 || 21 => 'st',
          2 || 22 => 'nd',
          3 || 23 => 'rd',
          _ => 'th',
        }}';

  Future<void> _manage(BuildContext context) async {
    final bloc = context.read<SquadLedgerBloc>();
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.sheet,
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(recurring.title, style: AppTextStyles.title(size: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              subtitle: const Text('Changes apply from the next charge'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: Icon(recurring.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              title: Text(recurring.isPaused ? 'Resume' : 'Pause'),
              subtitle: Text(
                recurring.isPaused
                    ? 'Charges start again from this month'
                    : 'No charges until you resume',
              ),
              onTap: () => Navigator.of(context).pop('pause'),
            ),
            ListTile(
              leading: Icon(Icons.stop_circle_outlined, color: AppColors.accent700),
              title: Text('Stop', style: TextStyle(color: AppColors.accent700)),
              subtitle: const Text('Months already charged stay'),
              onTap: () => Navigator.of(context).pop('stop'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await showExpenseSheet(context, teamId: teamId, me: me, editingMonthly: recurring);
      case 'pause':
        bloc.add(RecurringPausedChanged(recurring.id, paused: !recurring.isPaused));
      case 'stop':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.card,
            title: Text('Stop ${recurring.title}?'),
            content: const Text(
              "It won't be charged again. Months already charged stay in the squad.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Stop'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) bloc.add(RecurringDeleteRequested(recurring.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ledger.currency;
    final isAdmin = ledger.member(me)?.isAdmin ?? false;
    final canManage = recurring.canManage(me, isAdmin: isAdmin);
    final next = recurring.nextCharge(DateTime.now());
    final myShare = recurring.shareOf(me);
    final owing = recurring.payerId == me ? _stillOwing() : const <String, int>{};
    final row = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: recurring.isPaused
                ? AppColors.surface
                : categoryTone(recurring.category).background,
            borderRadius: AppRadius.sm,
          ),
          // The service it's for (YouTube, Netflix, …), or paused.
          child: Icon(
            recurring.isPaused ? Icons.pause_rounded : categoryIcon(recurring.category),
            size: 20,
            color: recurring.isPaused ? squadMuted : categoryTone(recurring.category).foreground,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recurring.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.title(size: 15, height: 1.3),
              ),
              Text(
                [
                  '${formatMoney(recurring.amountCents, currency)} on ${_day(recurring.chargeDay)}',
                  if (next != null) 'next ${formatShortDate(next)}' else 'paused',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
              ),
              Text(
                '${ledger.nameOf(recurring.payerId, me: me)} '
                '${recurring.payerId == me ? 'pay' : 'pays'} it'
                '${myShare > 0 && recurring.payerId != me ? ' · your share ${formatMoney(myShare, currency)}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
              ),
            ],
          ),
        ),
        if (recurring.isPaused)
          Text(
            'Paused',
            style: AppTextStyles.body(size: 12.5, weight: FontWeight.w800, color: squadMuted),
          )
        else if (canManage)
          Icon(Icons.more_horiz_rounded, size: 20, color: squadMuted),
      ],
    );
    return SquadCard(
      onTap: canManage ? () => _manage(context) : null,
      child: owing.isEmpty
          ? row
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row,
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_names(owing.keys)} still '
                        '${owing.length == 1 ? 'owes' : 'owe'} for this month',
                        style: AppTextStyles.body(size: 12.5, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      RemindButton(
                        teamId: teamId,
                        amounts: owing,
                        remindedToday: owing.keys.every((id) => ledger.remindedToday(me, id)),
                        label: 'Remind to pay',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// This month's charge: who in it still owes you, and how much — their
  /// share, or less if they've paid you part of what they owe.
  Map<String, int> _stillOwing() {
    final now = DateTime.now();
    final charge = ledger.expenses
        .where(
          (e) =>
              e.recurringId == recurring.id &&
              e.spentAt.toLocal().year == now.year &&
              e.spentAt.toLocal().month == now.month,
        )
        .firstOrNull;
    if (charge == null) return const {};
    return {
      for (final MapEntry(key: id, value: share) in charge.shares.entries)
        if (id != me)
          if (ledger.owedBetween(id, me, includePending: true) case final owed when owed > 0)
            id: share < owed ? share : owed,
    };
  }

  /// "Ko", "Ko & Min", or "Ko + 2".
  String _names(Iterable<String> ids) => switch (ids.toList()) {
    [final only] => ledger.nameOf(only),
    [final a, final b] => '${ledger.nameOf(a)} & ${ledger.nameOf(b)}',
    [final first, ...final rest] => '${ledger.nameOf(first)} + ${rest.length}',
    [] => '',
  };
}
