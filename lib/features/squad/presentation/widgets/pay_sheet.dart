import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/squad_member.dart';
import '../../domain/repositories/squad_repository.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// Pay [toId] back: their QR or bank details, an editable amount (less
/// for a partial payment), and a slip — or "paid in cash". It's sent as
/// pending; [toId] confirms before balances change.
Future<void> showPaySheet(
  BuildContext context, {
  required String teamId,
  required String me,
  required String toId,
  required int suggestedCents,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.neutral100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _PaySheet(teamId: teamId, me: me, toId: toId, suggestedCents: suggestedCents),
  );
}

class _PaySheet extends StatefulWidget {
  const _PaySheet({
    required this.teamId,
    required this.me,
    required this.toId,
    required this.suggestedCents,
  });

  final String teamId;
  final String me;
  final String toId;
  final int suggestedCents;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  late final _amount = TextEditingController(
    text: widget.suggestedCents > 0 ? moneyInput(widget.suggestedCents) : '',
  );
  SettlementMethod? _method;
  PickedImage? _slip;

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

  SettlementMethod _defaultMethod(SquadMember? receiver) => switch (receiver) {
    SquadMember(hasQr: true) => SettlementMethod.qr,
    SquadMember(hasBankDetails: true) => SettlementMethod.bank,
    _ => SettlementMethod.cash,
  };

  Future<void> _pickSlip() async {
    final picked = await pickWalletImage();
    if (picked != null && mounted) setState(() => _slip = picked);
  }

  void _send(SettlementMethod method) {
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
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        final name = state.ledger?.nameOf(widget.toId) ?? 'They';
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text('Sent — waiting for $name to confirm.')));
      },
      builder: (context, state) {
        final ledger = state.ledger ?? SquadLedger.empty;
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
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              const _Grabber(),
              Row(
                children: [
                  SquadAvatar(
                    initial: receiver?.initial ?? '?',
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
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
              Text(
                [
                  if (owed > 0) 'You owe ${formatMoney(owed, currency)}',
                  if (pending > 0) '${formatMoney(pending, currency)} already sent and waiting',
                  'pay less for a partial payment',
                ].join(' · '),
                style: AppTextStyles.body(size: 12, color: squadMuted),
              ),
              const SizedBox(height: 14),
              _MethodTabs(method: method, onChanged: (picked) => setState(() => _method = picked)),
              const SizedBox(height: 14),
              switch (method) {
                SettlementMethod.qr =>
                  receiver?.walletQrPath == null
                      ? _Missing("$name hasn't added a wallet QR yet. Try bank or cash.")
                      : _QrPanel(
                          path: receiver!.walletQrPath!,
                          caption:
                              'Scan in your banking or wallet app, pay '
                              '${formatMoney(amount, currency)}, then add the slip.',
                        ),
                SettlementMethod.bank =>
                  receiver?.hasBankDetails != true
                      ? _Missing("$name hasn't added bank details yet. Try QR or cash.")
                      : _BankPanel(member: receiver!),
                SettlementMethod.cash => _Missing(
                  'Hand $name ${formatMoney(amount, currency)} in cash, then tap below. '
                  'No slip needed.',
                  icon: Icons.payments_outlined,
                ),
              },
              if (needsSlip) ...[
                const SizedBox(height: 12),
                _SlipButton(slip: _slip, onPick: _pickSlip),
              ],
              const SizedBox(height: 16),
              SquadPrimaryButton(
                label: method == SettlementMethod.cash ? 'I paid in cash' : 'Send for confirmation',
                isLoading: state is SquadLedgerSubmitting,
                onPressed: canSend ? () => _send(method) : null,
              ),
              const SizedBox(height: 8),
              Text(
                '$name confirms before your balance changes.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(size: 12, color: squadMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.neutral400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _MethodTabs extends StatelessWidget {
  const _MethodTabs({required this.method, required this.onChanged});

  final SettlementMethod method;
  final ValueChanged<SettlementMethod> onChanged;

  static IconData _icon(SettlementMethod method) => switch (method) {
    SettlementMethod.qr => Icons.qr_code_2_rounded,
    SettlementMethod.bank => Icons.account_balance_outlined,
    SettlementMethod.cash => Icons.payments_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          for (final option in SettlementMethod.values)
            Expanded(
              child: Semantics(
                selected: option == method,
                button: true,
                child: Material(
                  color: option == method ? AppColors.neutral100 : Colors.transparent,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => onChanged(option),
                    child: SizedBox(
                      height: 38,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _icon(option),
                            size: 16,
                            color: option == method ? AppColors.text : squadMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            option.label,
                            style: AppTextStyles.body(
                              size: 13,
                              weight: FontWeight.w700,
                              color: option == method ? AppColors.text : squadMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.path, required this.caption});

  final String path;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Their wallet QR code',
          button: true,
          child: GestureDetector(
            onTap: () => showWalletImageViewer(
              context,
              kind: WalletImageKind.walletQr,
              path: path,
              title: 'Wallet QR',
            ),
            child: Container(
              width: 132,
              height: 132,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
              ),
              child: WalletImage(kind: WalletImageKind.walletQr, path: path),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(caption, style: AppTextStyles.body(size: 13, color: squadMuted)),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => saveWalletQr(context, path),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Save QR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  minimumSize: const Size(0, 44),
                  side: BorderSide(color: AppColors.text.withValues(alpha: 0.2)),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankPanel extends StatelessWidget {
  const _BankPanel({required this.member});

  final SquadMember member;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Bank', member.bankName),
      ('Name', member.bankAccountName),
      ('Account', member.bankAccountNo),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          for (final (label, value) in rows)
            if ((value ?? '').isNotEmpty)
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(label, style: AppTextStyles.body(size: 12.5, color: squadMuted)),
                  ),
                  Expanded(
                    child: Text(
                      value!,
                      style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy ${label.toLowerCase()}',
                    icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.accent700),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(content: Text('$label copied')));
                    },
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing(this.text, {this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: squadMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTextStyles.body(size: 13, color: squadMuted)),
          ),
        ],
      ),
    );
  }
}

class _SlipButton extends StatelessWidget {
  const _SlipButton({required this.slip, required this.onPick});

  final PickedImage? slip;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final picked = slip;
    return Material(
      color: AppColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.neutral500),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (picked != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(picked.bytes, width: 44, height: 44, fit: BoxFit.cover),
                )
              else
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.receipt_long_outlined, color: squadMuted),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  picked == null ? 'Add payment slip' : 'Slip added',
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                ),
              ),
              Text(
                picked == null ? 'Choose' : 'Change',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.accent700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
