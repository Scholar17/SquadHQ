import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/repositories/squad_repository.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'sheet_parts.dart';
import 'squad_widgets.dart';

/// Pay [toId] back: their QR or bank details, an editable amount (less
/// for a partial payment), and a slip — or "paid in cash". It's sent as
/// pending; [toId] confirms before balances change.
///
/// From one expense, [expenseCents] is what's left of it: the sheet then
/// offers paying just that or all you owe [toId] ([suggestedCents], the
/// default), so two expenses to the same person can go in one payment.
Future<void> showPaySheet(
  BuildContext context, {
  required String teamId,
  required String me,
  required String toId,
  required int suggestedCents,
  int? expenseCents,
  String? tripId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _PaySheet(
      teamId: teamId,
      me: me,
      toId: toId,
      suggestedCents: suggestedCents,
      expenseCents: expenseCents,
      tripId: tripId,
    ),
  );
}

class _PaySheet extends StatefulWidget {
  const _PaySheet({
    required this.teamId,
    required this.me,
    required this.toId,
    required this.suggestedCents,
    this.expenseCents,
    this.tripId,
  });

  final String teamId;
  final String me;
  final String toId;
  final int suggestedCents;

  /// Paying from one expense: what's left of it (see [showPaySheet]).
  final int? expenseCents;

  /// Paying back this (closed) trip, apart from the squad's own.
  final String? tripId;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final _amount = TextEditingController(
    text: _suggested > 0 ? moneyInput(_suggested) : '',
  );

  /// Paying just the expense it was opened from, not all you owe.
  bool _onlyThis = false;

  /// Whether there's a choice: the expense is less than all you owe.
  bool get _canChoose {
    final cents = widget.expenseCents;
    return cents != null && cents > 0 && cents < widget.suggestedCents;
  }

  /// What "Full" pays: this expense, or all you owe.
  int get _suggested => _onlyThis && _canChoose ? widget.expenseCents! : widget.suggestedCents;
  SettlementMethod? _method;
  PickedImage? _slip;
  final _amountFocus = FocusNode();

  /// Set from the tap until the send fails, so a fast double tap can't
  /// send the same payment (and slip) twice.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  SettlementMethod _defaultMethod(SquadMember? receiver) => switch (receiver) {
    SquadMember(hasQr: true) => SettlementMethod.qr,
    SquadMember(hasBankDetails: true) => SettlementMethod.bank,
    _ => SettlementMethod.cash,
  };

  /// Half of what's owed, rounded up to a whole unit (never more than it).
  int get _half {
    final half = ((_suggested / 2) / 100).ceil() * 100;
    return half > _suggested ? _suggested : half;
  }

  void _choose({required bool onlyThis}) {
    setState(() => _onlyThis = onlyThis);
    _setAmount(_suggested);
  }

  void _setAmount(int? cents) {
    _amount.text = cents == null ? '' : moneyInput(cents);
    if (cents == null) _amountFocus.requestFocus();
  }

  Future<void> _pickSlip() async {
    final picked = await pickWalletImage(context, slip: true);
    if (picked != null && mounted) setState(() => _slip = picked);
  }

  void _send(SettlementMethod method) {
    if (_sending) return;
    setState(() => _sending = true);
    final amount = parseMoney(_amount.text) ?? 0;
    context.read<SquadLedgerBloc>().add(
      SettlementSendRequested(
        SettlementDraft(
          teamId: widget.teamId,
          toId: widget.toId,
          amountCents: amount,
          method: method,
          slipBytes: _slip?.bytes,
          slipExtension: _slip?.fileExtension,
          tripId: widget.tripId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SquadLedgerBloc, SquadLedgerState>(
      listenWhen: (previous, current) =>
          current is SquadLedgerFailure ||
          (previous is SquadLedgerSubmitting && current is SquadLedgerLoaded),
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
        if (state case SquadLedgerFailure(:final message)) {
          setState(() => _sending = false);
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        final name = state.ledger?.nameOf(widget.toId) ?? 'They';
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text('Sent — waiting for $name to confirm.')));
      },
      builder: (context, state) {
        final full = state.ledger ?? SquadLedger.empty;
        final tripId = widget.tripId;
        final ledger = tripId == null ? full : full.forTrip(tripId);
        final currency = ledger.currency;
        final receiver = ledger.member(widget.toId);
        final name = ledger.nameOf(widget.toId);
        final method = _method ?? _defaultMethod(receiver);
        final amount = parseMoney(_amount.text) ?? 0;
        final pending = ledger.pendingCentsFrom(widget.me, to: widget.toId);
        final owed = widget.suggestedCents + pending;
        final needsSlip = method != SettlementMethod.cash;
        final canSend =
            amount > 0 &&
            (!needsSlip || _slip != null) &&
            switch (method) {
              SettlementMethod.qr => receiver?.hasQr ?? false,
              SettlementMethod.bank => receiver?.hasBankDetails ?? false,
              SettlementMethod.cash => true,
            };
        return StickyActionSheet(
          background: AppColors.card,
          action: SquadPrimaryButton(
            label: method == SettlementMethod.cash ? 'I paid in cash' : 'Send for confirmation',
            isLoading: _sending || state is SquadLedgerSubmitting,
            onPressed: canSend ? () => _send(method) : null,
          ),
          footer: Text(
            '$name confirms before your balance changes.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 12, color: squadMuted),
          ),
          children: [
            const SheetGrabber(),
            Row(
              children: [
                SquadAvatar(
                  initial: receiver?.initial ?? '?',
                  photoUrl: receiver?.avatarUrl,
                  size: 36,
                  color: AppColors.teamGold,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Pay $name', style: AppTextStyles.heading(size: 20))),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(currency.symbol, style: AppTextStyles.heading(size: 28, color: squadMuted)),
                const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    label: 'Amount to pay',
                    child: TextField(
                      controller: _amount,
                      focusNode: _amountFocus,
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
                ),
              ],
            ),
            // From an expense: just it, or everything you owe them.
            if (_canChoose) ...[
              const SizedBox(height: 10),
              _ScopeOption(
                label: 'All you owe $name',
                detail: switch (ledger.openExpenseCount(widget.me, widget.toId)) {
                  final n when n > 1 => 'Covers $n expenses',
                  _ => 'Everything still open between you',
                },
                amount: formatMoney(widget.suggestedCents, currency),
                selected: !_onlyThis,
                onTap: () => _choose(onlyThis: false),
              ),
              const SizedBox(height: 8),
              _ScopeOption(
                label: 'This expense only',
                amount: formatMoney(widget.expenseCents!, currency),
                selected: _onlyThis,
                onTap: () => _choose(onlyThis: true),
              ),
              const SizedBox(height: 12),
            ],
            // Pay it all, half, or any part.
            if (_suggested > 0) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SquadChoiceChip(
                    label: 'Full',
                    selected: amount == _suggested,
                    onTap: () => _setAmount(_suggested),
                  ),
                  if (_half < _suggested)
                    SquadChoiceChip(
                      label: 'Half · ${formatMoney(_half, currency)}',
                      selected: amount == _half,
                      onTap: () => _setAmount(_half),
                    ),
                  SquadChoiceChip(
                    label: 'Custom',
                    selected: amount != _suggested && amount != _half,
                    onTap: () => _setAmount(null),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text(
              [
                if (owed > 0) 'You owe ${formatMoney(owed, currency)}',
                if (pending > 0) '${formatMoney(pending, currency)} already sent and waiting',
                if (amount > 0 && amount < widget.suggestedCents)
                  '${formatMoney(widget.suggestedCents - amount, currency)} left after this'
                else if (_suggested > 0)
                  'or pay part of it',
              ].join(' · '),
              style: AppTextStyles.body(size: 12, color: squadMuted),
            ),
            const SizedBox(height: 14),
            PaymentMethodTabs(method: method, onChanged: (picked) => setState(() => _method = picked)),
            const SizedBox(height: 14),
            switch (method) {
              SettlementMethod.qr =>
                receiver?.walletQrPath == null
                    ? SheetNotice("$name hasn't added a wallet QR yet. Try bank or cash.")
                    : WalletQrPanel(
                        path: receiver!.walletQrPath!,
                        caption:
                            'Scan in your banking or wallet app, pay '
                            '${formatMoney(amount, currency)}, then add the slip.',
                      ),
              SettlementMethod.bank =>
                receiver?.hasBankDetails != true
                    ? SheetNotice("$name hasn't added bank details yet. Try QR or cash.")
                    : BankDetailsPanel(member: receiver!),
              SettlementMethod.cash => SheetNotice(
                'Hand $name ${formatMoney(amount, currency)} in cash, then tap below. '
                'No slip needed.',
                icon: Icons.payments_outlined,
              ),
            },
            if (needsSlip) ...[
              const SizedBox(height: 12),
              SlipPickerButton(slip: _slip, onPick: _pickSlip),
            ],
          ],
        );
      },
    );
  }
}

/// One of "All you owe …" / "This expense only": a radio-style row.
class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.label,
    required this.amount,
    required this.selected,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String amount;
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.md,
          side: BorderSide(
            color: selected ? AppColors.accent700 : AppColors.text.withValues(alpha: 0.15),
          ),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? AppColors.accent700 : squadMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.body(size: 14, weight: FontWeight.w700)),
                      if (detail != null)
                        Text(detail, style: AppTextStyles.body(size: 12, color: squadMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(amount, style: AppTextStyles.body(size: 14, weight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
