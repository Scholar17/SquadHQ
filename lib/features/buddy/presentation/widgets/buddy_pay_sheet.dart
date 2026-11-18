import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/money_input_formatter.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../../squad/domain/entities/settlement.dart' show SettlementMethod;
import '../../../squad/domain/entities/squad_ledger.dart';
import '../../../squad/presentation/squad_formatting.dart';
import '../../../squad/presentation/widgets/sheet_parts.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../wallet/presentation/widgets/wallet_image_actions.dart';
import '../../domain/repositories/buddy_repository.dart';
import '../cubit/buddy_cubit.dart';

/// Paying back on buddy expenses. You owe [otherId] ([received] false):
/// "I paid" — by cash, their QR or bank, with an optional slip — waits for
/// them to confirm. They owe you ([received] true): "Mark as received",
/// settled straight away.
Future<void> showBuddyPaySheet(
  BuildContext context, {
  required String teamId,
  required String me,
  required String otherId,
  required int owedCents,
  required SquadLedger ledger,
  bool received = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: AppColors.card,
  shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
  builder: (_) => BlocProvider.value(
    value: sl<BuddyCubit>(),
    child: _BuddyPaySheet(
      teamId: teamId,
      me: me,
      otherId: otherId,
      owedCents: owedCents,
      ledger: ledger,
      received: received,
    ),
  ),
);

class _BuddyPaySheet extends StatefulWidget {
  const _BuddyPaySheet({
    required this.teamId,
    required this.me,
    required this.otherId,
    required this.owedCents,
    required this.ledger,
    required this.received,
  });

  final String teamId;
  final String me;
  final String otherId;
  final int owedCents;
  final SquadLedger ledger;
  final bool received;

  @override
  State<_BuddyPaySheet> createState() => _BuddyPaySheetState();
}

class _BuddyPaySheetState extends State<_BuddyPaySheet> {
  late final _amount = TextEditingController(text: moneyInput(widget.owedCents));

  /// Paying them: their QR if they've added one, else bank, else cash.
  /// Marking it received: cash until you say otherwise.
  late SettlementMethod _method = switch (widget.ledger.member(widget.otherId)) {
    _ when widget.received => SettlementMethod.cash,
    final other? when other.hasQr => SettlementMethod.qr,
    final other? when other.hasBankDetails => SettlementMethod.bank,
    _ => SettlementMethod.cash,
  };
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

  Future<void> _save() async {
    final amount = parseMoney(_amount.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    final saved = await context.read<BuddyCubit>().pay(
      BuddyPaymentDraft(
        teamId: widget.teamId,
        fromId: widget.received ? widget.otherId : widget.me,
        toId: widget.received ? widget.me : widget.otherId,
        amountCents: amount,
        method: _method,
        slipBytes: _slip?.bytes,
        slipExtension: _slip?.fileExtension,
      ),
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
    final currency = ledger.currency;
    final name = ledger.nameOf(widget.otherId);
    final other = ledger.member(widget.otherId);
    final saving = context.watch<BuddyCubit>().state.saving;
    final amount = parseMoney(_amount.text) ?? 0;
    final received = widget.received;
    return BlocListener<BuddyCubit, BuddyState>(
      listenWhen: (previous, current) => current.error != null && previous.error != current.error,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error!))),
      child: StickyActionSheet(
        background: AppColors.card,
        action: SquadPrimaryButton(
          label: received ? 'Mark as received' : 'I paid',
          isLoading: saving,
          onPressed: saving ? null : _save,
        ),
        footer: Text(
          received
              ? 'Settled straight away for both of you.'
              : '$name confirms it, then your buddy balance updates.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 12, color: squadMuted),
        ),
        children: [
          const SheetGrabber(),
          SheetHeader(
            title: received ? 'Got money from $name' : 'Pay $name',
            leading: SquadAvatar(
              initial: other?.initial ?? '?',
              photoUrl: other?.avatarUrl,
              size: 36,
              color: AppColors.teamGold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(currency.symbol, style: AppTextStyles.heading(size: 28, color: squadMuted)),
              const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  label: received ? 'Amount received' : 'Amount to pay',
                  child: TextField(
                    key: const ValueKey('buddy-pay-amount'),
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
              ),
            ],
          ),
          Text(
            [
              '${received ? '$name owes you' : 'You owe $name'} ${formatMoney(widget.owedCents, currency)}',
              if (amount > 0 && amount < widget.owedCents)
                '${formatMoney(widget.owedCents - amount, currency)} left after this'
              else
                'or ${received ? 'record' : 'pay'} part of it',
            ].join(' · '),
            style: AppTextStyles.body(size: 12, color: squadMuted),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: received ? 'HOW THEY PAID' : 'HOW',
            child: PaymentMethodTabs(method: _method, onChanged: (picked) => setState(() => _method = picked)),
          ),
          // Paying them: their QR or bank to pay to, then an optional slip.
          if (!received) ...[
            const SizedBox(height: 14),
            switch (_method) {
              SettlementMethod.qr => other?.walletQrPath == null
                  ? SheetNotice("$name hasn't added a wallet QR yet. Try bank or cash.")
                  : WalletQrPanel(
                      path: other!.walletQrPath!,
                      caption:
                          'Scan in your banking or wallet app, pay '
                          '${formatMoney(amount, currency)}, then add the slip.',
                    ),
              SettlementMethod.bank => other?.hasBankDetails != true
                  ? SheetNotice("$name hasn't added bank details yet. Try QR or cash.")
                  : BankDetailsPanel(member: other!),
              SettlementMethod.cash => SheetNotice(
                'Hand $name ${formatMoney(amount, currency)} in cash, then tap below.',
                icon: Icons.payments_outlined,
              ),
            },
            if (_method != SettlementMethod.cash) ...[
              const SizedBox(height: 12),
              SlipPickerButton(
                slip: _slip,
                label: 'Add payment slip (optional)',
                onPick: () async {
                  final picked = await pickWalletImage(context, slip: true);
                  if (picked != null && mounted) setState(() => _slip = picked);
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
