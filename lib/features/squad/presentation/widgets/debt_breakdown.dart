import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// "47% of your ฿250 share — Aung & Ko paid": why [debtorId] owes one
/// payer only part of their share when several people paid [expense].
/// Null with one payer, or when the part is the whole share.
String? splitPayersNote(
  Expense expense,
  String debtorId,
  int cents,
  SquadLedger ledger,
  String me,
) {
  final short = -expense.netFor(debtorId);
  if (!expense.hasSeveralPayers || short <= 0 || cents >= short) return null;
  final whose = debtorId == me ? 'your' : "${ledger.nameOf(debtorId)}'s";
  return '${(cents * 100 / short).round()}% of $whose '
      '${formatMoney(short, ledger.currency)} share — '
      '${ledger.paidByLabel(expense, me: me)} paid';
}

/// What [fromId] owes [toId] for, as on a Settle card — the newest
/// expense behind it, by name; any others only as a number: "For YouTube
/// Family · Oct 2026", or "… and 2 earlier". For a single expense several
/// people paid, which part of the share it is ("67% of your ฿300 Dinner
/// share — Aung & Ko paid"). Null when nothing's owed.
String? debtForWhat(SquadLedger ledger, String fromId, String toId, String me) {
  final lines = ledger.debtLines(fromId, toId, includePending: true);
  // Oldest first; the newest is what this debt is most likely about.
  final adds = [
    for (final line in lines)
      if (line.cents > 0 && line.expense != null) line,
  ];
  if (adds.isEmpty) return lines.any((line) => line.cents > 0) ? 'Extra payment' : null;
  final newest = adds.last;
  final title = newest.expense!.title;
  if (adds.length == 1) {
    return splitPayersNote(
          newest.expense!,
          fromId,
          newest.fullCents ?? newest.cents,
          ledger,
          me,
        )?.replaceFirst(' share', ' $title share') ??
        'For $title';
  }
  return 'For $title and ${adds.length - 1} earlier';
}

/// Payments between [fromId] and [toId] still waiting for the receiver,
/// which the open amount already counts as paid: "฿200 sent · waiting for
/// Aung to confirm", or "Includes ฿25 Aung sent you · confirm it in To
/// confirm". Null when none.
String? pendingNote(SquadLedger ledger, String fromId, String toId, String me) {
  final currency = ledger.currency;
  String name(String id) => ledger.nameOf(id, me: me);
  final sent = ledger.pendingCentsFrom(fromId, to: toId);
  final back = ledger.pendingCentsFrom(toId, to: fromId);
  final notes = [
    if (sent > 0)
      if (fromId == me)
        '${formatMoney(sent, currency)} sent · waiting for ${name(toId)} to confirm'
      else if (toId == me)
        '${name(fromId)} sent you ${formatMoney(sent, currency)} · confirm it in To confirm'
      else
        '${formatMoney(sent, currency)} sent · waiting',
    if (back > 0)
      if (fromId == me)
        'Includes ${formatMoney(back, currency)} ${name(toId)} sent you · confirm it in To confirm'
      else if (toId == me)
        'Includes ${formatMoney(back, currency)} you sent ${name(fromId)} · waiting for them'
      else
        'Includes ${formatMoney(back, currency)} sent back · waiting',
  ];
  return notes.isEmpty ? null : notes.join('\n');
}

/// How what's owed between [me] and [otherId] is worked out, as a short
/// sum: "Mg Mg owes you for ฿1,000 · You owe Mg Mg for −฿500 · ฿1,000 −
/// ฿500 = ฿500 · Mg Mg pays you ฿500". Each line opens to the expenses or
/// payments behind it. Payments still waiting count, marked Pending.
class PairStatementView extends StatefulWidget {
  const PairStatementView({
    super.key,
    required this.ledger,
    required this.me,
    required this.otherId,
  });

  final SquadLedger ledger;
  final String me;
  final String otherId;

  @override
  State<PairStatementView> createState() => _PairStatementViewState();
}

/// One line of the sum and what's behind it.
typedef _SumLine = ({String key, String label, int cents, List<Widget> items});

class _PairStatementViewState extends State<PairStatementView> {
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
    final me = widget.me;
    final currency = ledger.currency;
    final name = ledger.nameOf(widget.otherId);
    final statement = ledger.statement(me, widget.otherId);
    final total = statement.total;
    final iPay = total >= 0;

    Widget expenseItem(Expense expense, int cents) => _Item(
      icon: categoryIcon(expense.category),
      title: expense.title,
      detail: formatShortDate(expense.spentAt),
      amount: formatMoney(cents, currency),
      onTap: () => context.push(AppRoutes.expenseDetail(expense.id)),
    );
    Widget paymentItem(Settlement p) => _Item(
      icon: p.isPending ? Icons.schedule_rounded : Icons.check_rounded,
      title: '${p.method.label} · ${formatShortDate(p.respondedAt ?? p.createdAt)}',
      detail: switch (p) {
        _ when p.isPending => 'Pending — counted as paid',
        Settlement(isPartlyReceived: true, :final sentCents?) =>
          'Got ${formatMoney(p.amountCents, currency)} of ${formatMoney(sentCents, currency)} sent',
        Settlement(:final recordedBy?) => 'Recorded by ${ledger.nameOf(recordedBy, me: me)}',
        _ => 'Confirmed',
      },
      amount: formatMoney(p.amountCents, currency),
    );

    final mine = statement.aOwes; // You owe them for these.
    final theirs = statement.bOwes; // They owe you for these.
    final paidByMe = [
      for (final p in statement.payments)
        if (p.fromId == me) p,
    ];
    final paidByThem = [
      for (final p in statement.payments)
        if (p.fromId != me) p,
    ];
    int sumOf(List<({Expense expense, int cents})> items) =>
        items.fold<int>(0, (s, x) => s + x.cents);
    int paid(List<Settlement> items) => items.fold<int>(0, (s, p) => s + p.amountCents);

    final youOwe = (
      key: 'you-owe',
      label: 'You owe $name for',
      cents: sumOf(mine),
      items: [for (final (:expense, :cents) in mine) expenseItem(expense, cents)],
    );
    final theyOwe = (
      key: 'they-owe',
      label: '$name owes you for',
      cents: sumOf(theirs),
      items: [for (final (:expense, :cents) in theirs) expenseItem(expense, cents)],
    );
    final youPaid = (
      key: 'you-paid',
      label: 'You already paid $name',
      cents: paid(paidByMe),
      items: [for (final p in paidByMe) paymentItem(p)],
    );
    final theyPaid = (
      key: 'they-paid',
      label: '$name already paid you',
      cents: paid(paidByThem),
      items: [for (final p in paidByThem) paymentItem(p)],
    );
    // Toward the result first (+), then what takes it down (−).
    final lines = <(_SumLine, bool)>[
      if (iPay) ...[
        (youOwe, true),
        (theyOwe, false),
        (youPaid, false),
        (theyPaid, true),
      ] else ...[
        (theyOwe, true),
        (youOwe, false),
        (theyPaid, false),
        (youPaid, true),
      ],
    ].where((l) => l.$1.cents > 0).toList();

    final formula = [
      for (final (i, (line, plus)) in lines.indexed)
        '${i == 0 ? (plus ? '' : '−') : (plus ? '+ ' : '− ')}${formatMoney(line.cents, currency)}',
    ].join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (line, plus) in lines) ...[
          InkWell(
            borderRadius: AppRadius.sm,
            onTap: () => setState(() {
              if (!_open.remove(line.key)) _open.add(line.key);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line.label,
                      style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${plus ? '' : '−'}${formatMoney(line.cents, currency)}',
                    style: AppTextStyles.body(
                      size: 14.5,
                      weight: FontWeight.w800,
                      color: plus ? null : squadMuted,
                    ),
                  ),
                  Icon(
                    _open.contains(line.key)
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: squadMuted,
                  ),
                ],
              ),
            ),
          ),
          // What's behind it, folded away until asked for.
          if (_open.contains(line.key))
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Column(children: line.items),
            ),
        ],
        const Divider(height: 20),
        if (lines.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '$formula = ${formatMoney(total.abs(), currency)}',
              style: AppTextStyles.body(size: 13, color: squadMuted, weight: FontWeight.w600),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Text(switch (total) {
                > 0 => 'You pay $name',
                < 0 => '$name pays you',
                _ => 'All square',
              }, style: AppTextStyles.body(size: 15, weight: FontWeight.w800)),
            ),
            Text(
              formatMoney(total.abs(), currency),
              style: AppTextStyles.body(
                size: 16,
                weight: FontWeight.w800,
                color: total > 0 ? oweColor : (total < 0 ? owedColor : null),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One expense or payment under a line of the sum.
class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.detail,
    required this.amount,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.sm,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: squadMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 13, weight: FontWeight.w600, height: 1.3),
                  ),
                  Text(
                    detail,
                    style: AppTextStyles.body(size: 11.5, color: squadMuted, height: 1.3),
                  ),
                ],
              ),
            ),
            Text(amount, style: AppTextStyles.body(size: 13, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
