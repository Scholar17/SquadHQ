import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/repositories/squad_repository.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// "You said you'd pay on Sat 25 Oct" / "Ko will pay you on Sat 25 Oct" —
/// [fromId]'s promise to pay [toId], while it's still to come. Null when
/// there's none.
String? promiseNote(SquadLedger ledger, String fromId, String toId, String me) {
  final promise = ledger.promiseFrom(fromId, toId);
  if (promise == null) return null;
  final day = formatShortDate(promise.promisedOn);
  final today = promise.isDueToday();
  if (fromId == me) {
    return today ? 'Today’s the day you said you’d pay' : 'You said you’d pay on $day';
  }
  final name = ledger.nameOf(fromId);
  return today ? '$name said they’d pay today' : '$name will pay you on $day';
}

/// "Paid ฿500 of ฿1,000 so far" — when [fromId] has paid [toId] part of
/// what's still open between them. Null otherwise.
String? partlyPaidNote(SquadLedger ledger, String fromId, String toId, String me) {
  final part = ledger.partlyPaid(fromId, toId);
  if (part == null) return null;
  final currency = ledger.currency;
  final of =
      '${formatMoney(part.paid, currency)} of ${formatMoney(part.paid + part.left, currency)} '
      'so far';
  return fromId == me ? 'Paid $of' : '${ledger.nameOf(fromId)} paid $of';
}

/// " · part of ฿1,000" after a pending payment that covers only part of
/// what's owed; empty otherwise.
String partialLabel(SquadLedger ledger, Settlement settlement) => switch (ledger.partOf(
  settlement,
)) {
  final part? => ' · part of ${formatMoney(part.owed, ledger.currency)}',
  null => '',
};

/// Reminders to [fromId] about what they owe [toId] wait: they promised a
/// day that hasn't come yet.
bool remindersWait(SquadLedger ledger, String fromId, String toId) =>
    ledger.promiseFrom(fromId, toId)?.isAhead() ?? false;

/// Dispatches [event] and waits for the outcome: null once it's saved, or
/// the error message.
Future<String?> _submit(SquadLedgerBloc bloc, SquadLedgerEvent event) async {
  final outcome = bloc.stream
      .skipWhile((state) => state is! SquadLedgerSubmitting)
      .firstWhere((state) => state is SquadLedgerLoaded || state is SquadLedgerFailure);
  bloc.add(event);
  return switch (await outcome) {
    SquadLedgerFailure(:final message) => message,
    _ => null,
  };
}

void _snack(ScaffoldMessengerState messenger, String text) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

/// "Pay later": the payer picks the day they'll pay [toId] — from tomorrow,
/// within two months. Reminders about it wait until then.
Future<void> promiseToPay(
  BuildContext context, {
  required String teamId,
  required String toId,
  String? tripId,
}) async {
  final bloc = context.read<SquadLedgerBloc>();
  final messenger = ScaffoldMessenger.of(context);
  final name = bloc.state.ledger?.nameOf(toId) ?? 'them';
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final day = await showDatePicker(
    context: context,
    initialDate: tomorrow,
    firstDate: tomorrow,
    lastDate: tomorrow.add(const Duration(days: 59)),
    helpText: 'WHEN WILL YOU PAY ${name.toUpperCase()}?',
    confirmText: 'Promise',
  );
  if (day == null) return;
  final error = await _submit(
    bloc,
    PaymentPromised(PromiseDraft(teamId: teamId, toId: toId, on: day, tripId: tripId)),
  );
  _snack(
    messenger,
    error ??
        'Told $name you’ll pay on ${formatShortDate(day)}. '
            'Reminders wait until then.',
  );
}

/// "Got cash": whoever's owed records cash [fromId] handed them —
/// confirmed straight away.
Future<void> showGotCashSheet(
  BuildContext context, {
  required String teamId,
  required String fromId,
  required int owedCents,
  String? tripId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.sheet,
    ),
    builder: (_) => BlocProvider.value(
      value: context.read<SquadLedgerBloc>(),
      child: _GotCashSheet(teamId: teamId, fromId: fromId, owedCents: owedCents, tripId: tripId),
    ),
  );
}

class _GotCashSheet extends StatefulWidget {
  const _GotCashSheet({
    required this.teamId,
    required this.fromId,
    required this.owedCents,
    this.tripId,
  });

  final String teamId;
  final String fromId;
  final int owedCents;
  final String? tripId;

  @override
  State<_GotCashSheet> createState() => _GotCashSheetState();
}

class _GotCashSheetState extends State<_GotCashSheet> {
  late final _amount = TextEditingController(text: moneyInput(widget.owedCents));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _record(int cents, String name, SquadLedger ledger) async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await _submit(
      context.read<SquadLedgerBloc>(),
      ReceivedRecorded(
        ReceivedDraft(
          teamId: widget.teamId,
          fromId: widget.fromId,
          amountCents: cents,
          tripId: widget.tripId,
        ),
      ),
    );
    if (error != null) {
      if (mounted) setState(() => _saving = false);
      _snack(messenger, error);
      return;
    }
    navigator.pop();
    _snack(
      messenger,
      'Recorded ${formatMoney(cents, ledger.currency)} cash from $name. '
      'Balances are updated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledger = context.read<SquadLedgerBloc>().state.ledger ?? SquadLedger.empty;
    final name = ledger.nameOf(widget.fromId);
    final currency = ledger.currency;
    final amount = parseMoney(_amount.text) ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          Text('GOT CASH', style: AppTextStyles.label(color: squadMuted)),
          const SizedBox(height: 4),
          Text('$name paid you in cash', style: AppTextStyles.heading(size: 22, height: 1.2)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(currency.symbol, style: AppTextStyles.heading(size: 28, color: squadMuted)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  key: const ValueKey('cash-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [MoneyInputFormatter()],
                  style: AppTextStyles.heading(size: 36),
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          Text(
            [
              'They owe you ${formatMoney(widget.owedCents, currency)}',
              if (amount > 0 && amount < widget.owedCents)
                '${formatMoney(widget.owedCents - amount, currency)} left after this',
            ].join(' · '),
            style: AppTextStyles.body(size: 12, color: squadMuted),
          ),
          const SizedBox(height: 18),
          SquadPrimaryButton(
            label: amount > 0 ? 'Record ${formatMoney(amount, currency)} received' : 'Record',
            color: AppColors.successFill,
            isLoading: _saving,
            onPressed: amount > 0 && !_saving ? () => _record(amount, name, ledger) : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Counts straight away — you’re the one who’d confirm it. $name gets a notification.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 12, color: squadMuted),
          ),
        ],
      ),
    );
  }
}

/// "Your reminder day": when you get the "you owe" reminder each month —
/// the last day, or a day you pick (payday).
Future<void> showReminderDaySheet(
  BuildContext context, {
  required String teamId,
  required int? current,
}) {
  final bloc = context.read<SquadLedgerBloc>();
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.sheet,
    ),
    builder: (sheetContext) {
      Future<void> pick(int? day) async {
        Navigator.of(sheetContext).pop();
        if (day == current) return;
        final error = await _submit(bloc, ReminderDayChanged(teamId: teamId, day: day));
        _snack(
          messenger,
          error ??
              (day == null
                  ? 'You’ll be reminded on the last day of the month.'
                  : 'You’ll be reminded on the ${ordinal(day)} of each month.'),
        );
      }

      return ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('REMINDER DAY', style: AppTextStyles.label(color: squadMuted)),
          const SizedBox(height: 4),
          Text('When should we remind you?', style: AppTextStyles.heading(size: 22)),
          const SizedBox(height: 4),
          Text(
            'If you still owe anyone in this squad, you get one reminder that evening. '
            'Pick your payday.',
            style: AppTextStyles.body(size: 13, color: squadMuted),
          ),
          const SizedBox(height: 14),
          SquadChoiceChip(
            label: 'Last day of the month',
            selected: current == null,
            onTap: () => pick(null),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var day = 1; day <= 28; day++)
                _DayButton(day: day, selected: current == day, onTap: () => pick(day)),
            ],
          ),
        ],
      );
    },
  );
}

/// One day of the month, round, in the reminder-day grid.
class _DayButton extends StatelessWidget {
  const _DayButton({required this.day, required this.selected, required this.onTap});

  final int day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: 'Day $day',
      child: Material(
        color: selected ? AppColors.neutral900 : AppColors.card,
        shape: CircleBorder(
          side: BorderSide(
            color: selected ? AppColors.neutral900 : AppColors.text.withValues(alpha: 0.14),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                '$day',
                style: AppTextStyles.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: selected ? AppColors.onDark : AppColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1st, 2nd, 3rd, 4th … 21st, 22nd.
String ordinal(int n) {
  final suffix = (n % 100 >= 11 && n % 100 <= 13)
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}
