import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// The receiver checks a payment sent to them: the slip, amount and
/// method, then "Received" — or "I got a different amount" to confirm
/// only what arrived (the rest still owed), or "Reject" with a reason,
/// which sends it back so the payer can try again.
Future<void> showConfirmPaymentSheet(BuildContext context, {required Settlement settlement}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.sheet,
    ),
    builder: (_) => _ConfirmPaymentSheet(settlement: settlement),
  );
}

class _ConfirmPaymentSheet extends StatefulWidget {
  const _ConfirmPaymentSheet({required this.settlement});

  final Settlement settlement;

  @override
  State<_ConfirmPaymentSheet> createState() => _ConfirmPaymentSheetState();
}

class _ConfirmPaymentSheetState extends State<_ConfirmPaymentSheet> {
  static const _reasons = ['Amount is wrong', 'Nothing arrived', 'Wrong slip'];

  bool _rejecting = false;
  String? _reason;

  /// Confirming only part of it: what arrived.
  bool _partial = false;
  final _received = TextEditingController();

  /// Which answer was sent, for the snackbar once it's saved.
  bool? _accepted;

  /// What was confirmed when only part arrived.
  int? _partlyReceived;

  /// Captured before it's confirmed (the ledger changes after): what the
  /// payer still owes once this goes through, when it's a partial payment.
  int? _leftAfter;

  @override
  void initState() {
    super.initState();
    _received.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _received.dispose();
    super.dispose();
  }

  void _confirmPartly(int cents) {
    _accepted = true;
    _partlyReceived = cents;
    context.read<SquadLedgerBloc>().add(
      SettlementPartlyReceived(widget.settlement.id, receivedCents: cents),
    );
  }

  void _answer({required bool accept}) {
    _accepted = accept;
    context.read<SquadLedgerBloc>().add(
      SettlementAnswered(widget.settlement.id, accept: accept, reason: accept ? null : _reason),
    );
  }

  static String _methodLabel(SettlementMethod method) => switch (method) {
    SettlementMethod.qr => 'QR transfer + slip',
    SettlementMethod.bank => 'Bank transfer + slip',
    SettlementMethod.cash => 'Cash',
  };

  @override
  Widget build(BuildContext context) {
    final settlement = widget.settlement;
    return BlocConsumer<SquadLedgerBloc, SquadLedgerState>(
      listenWhen: (previous, current) =>
          current is SquadLedgerFailure ||
          (previous is SquadLedgerSubmitting && current is SquadLedgerLoaded),
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        if (state case SquadLedgerFailure(:final message)) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        final name = state.ledger?.nameOf(settlement.fromId) ?? 'They';
        final currency = state.ledger?.currency ?? SquadLedger.empty.currency;
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch ((_accepted, _partlyReceived, _leftAfter)) {
              (true, final got?, _) =>
                'Confirmed ${formatMoney(got, currency)}. The other '
                    '${formatMoney(settlement.amountCents - got, currency)} still counts as owed.',
              (true, _, final left?) =>
                'Partial payment confirmed. $name still owes you ${formatMoney(left, currency)}.',
              (true, _, _) => 'Payment confirmed. Balances are updated.',
              _ => 'Sent back to $name — they can send it again.',
            }),
          ),
        );
      },
      builder: (context, state) {
        final ledger = state.ledger ?? SquadLedger.empty;
        final name = ledger.nameOf(settlement.fromId);
        final isSubmitting = state is SquadLedgerSubmitting;
        final slip = settlement.slipPath;
        final received = parseMoney(_received.text) ?? 0;
        // Less than they owe you: say so plainly, before you confirm.
        final part = ledger.partOf(settlement);
        if (state is! SquadLedgerSubmitting) _leftAfter = part?.left;
        final validPart = received > 0 && received < settlement.amountCents;
        final actionWidget = Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: isSubmitting
                      ? null
                      : () => setState(() {
                          if (_partial) {
                            _partial = false;
                            _received.clear();
                            return;
                          }
                          _rejecting = !_rejecting;
                          _reason = null;
                        }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: AppColors.text.withValues(alpha: 0.2)),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _rejecting || _partial ? 'Cancel' : 'Reject',
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w700),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SquadPrimaryButton(
                label: _rejecting
                    ? 'Send back'
                    : _partial
                    ? (validPart ? 'Confirm ${formatMoney(received, ledger.currency)}' : 'Confirm')
                    : 'Received',
                color: _rejecting ? AppColors.accentFill : AppColors.successFill,
                isLoading: isSubmitting,
                onPressed: switch ((_rejecting, _partial)) {
                  (true, _) when _reason == null => null,
                  (true, _) => () => _answer(accept: false),
                  (_, true) when !validPart => null,
                  (_, true) => () => _confirmPartly(received),
                  _ => () => _answer(accept: true),
                },
              ),
            ),
          ],
        );
        return StickyActionSheet(
          background: AppColors.card,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          action: actionWidget,
          children: [
            Text(
              part == null ? 'PAYMENT TO CONFIRM' : 'PARTIAL PAYMENT TO CONFIRM',
              style: AppTextStyles.label(color: part == null ? squadMuted : oweColor),
            ),
            const SizedBox(height: 4),
            Text(
              part == null ? '$name says they paid you' : '$name paid you part of what they owe',
              style: AppTextStyles.heading(size: 22, height: 1.2),
            ),
            if (part != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('partial-notice'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.teamGold.withValues(alpha: 0.18),
                  borderRadius: AppRadius.md,
                  border: Border.all(color: AppColors.teamGold.withValues(alpha: 0.6)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 20, color: oweColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This is a partial payment: '
                        '${formatMoney(settlement.amountCents, ledger.currency)} of the '
                        '${formatMoney(part.owed, ledger.currency)} $name owes you. '
                        'After you confirm, they still owe '
                        '${formatMoney(part.left, ledger.currency)}.',
                        style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (slip != null) ...[
                  Semantics(
                    label: "Open $name's payment slip",
                    button: true,
                    child: GestureDetector(
                      onTap: () => showWalletImageViewer(
                        context,
                        kind: WalletImageKind.paymentSlip,
                        path: slip,
                        title: "$name's slip",
                      ),
                      child: Container(
                        width: 96,
                        height: 128,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: AppRadius.md,
                          border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                        ),
                        child: WalletImage(
                          kind: WalletImageKind.paymentSlip,
                          path: slip,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    children: [
                      _Fact(
                        'Amount',
                        part == null
                            ? formatMoney(settlement.amountCents, ledger.currency)
                            : '${formatMoney(settlement.amountCents, ledger.currency)} of '
                                  '${formatMoney(part.owed, ledger.currency)}',
                      ),
                      if (part != null)
                        _Fact('Left', formatMoney(part.left, ledger.currency)),
                      _Fact('Method', _methodLabel(settlement.method)),
                      _Fact(
                        'Sent',
                        '${formatShortDate(settlement.createdAt)}, '
                            '${formatMatchTime(settlement.createdAt)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              "Check your bank or wallet app first. $name's balance changes only when you confirm.",
              style: AppTextStyles.body(size: 13, color: squadMuted),
            ),
            if (!_rejecting && !_partial)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: isSubmitting ? null : () => setState(() => _partial = true),
                  style: TextButton.styleFrom(
                    foregroundColor: oweColor,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    'I got a different amount',
                    style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700, color: oweColor),
                  ),
                ),
              ),
            if (_partial) ...[
              const SizedBox(height: 14),
              Text('HOW MUCH ARRIVED?', style: AppTextStyles.label(color: squadMuted)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    ledger.currency.symbol,
                    style: AppTextStyles.heading(size: 24, color: squadMuted),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('received-amount'),
                      controller: _received,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [MoneyInputFormatter()],
                      style: AppTextStyles.heading(size: 28),
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
                received >= settlement.amountCents
                    ? 'That’s all of it — tap Cancel, then Received.'
                    : received > 0
                    ? 'The other ${formatMoney(settlement.amountCents - received, ledger.currency)} '
                          'still counts as owed by $name.'
                    : 'Less than ${formatMoney(settlement.amountCents, ledger.currency)}. '
                          'The rest still counts as owed.',
                style: AppTextStyles.body(size: 12.5, color: squadMuted),
              ),
            ],
            if (_rejecting) ...[
              const SizedBox(height: 14),
              Text('WHY?', style: AppTextStyles.label(color: squadMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in _reasons)
                    SquadChoiceChip(
                      label: reason,
                      selected: reason == _reason,
                      onTap: () => setState(() => _reason = reason),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: AppTextStyles.body(size: 12.5, color: squadMuted)),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.body(size: 14, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
