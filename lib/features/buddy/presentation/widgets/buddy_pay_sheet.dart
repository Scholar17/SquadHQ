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
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart' show WalletImageKind;
import '../../../wallet/presentation/widgets/wallet_image.dart';
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
  late SettlementMethod _method = widget.received || !(widget.ledger.member(widget.otherId)?.hasQr ?? false)
      ? SettlementMethod.cash
      : SettlementMethod.qr;
  PickedImage? _slip;

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
    final name = ledger.nameOf(widget.otherId);
    final other = ledger.member(widget.otherId);
    final saving = context.watch<BuddyCubit>().state.saving;
    return BlocListener<BuddyCubit, BuddyState>(
      listenWhen: (previous, current) => current.error != null && previous.error != current.error,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error!))),
      child: StickyActionSheet(
        background: AppColors.card,
        summary: Text(
          widget.received
              ? 'Settled straight away for both of you.'
              : '$name confirms it, then your buddy balance updates.',
          style: AppTextStyles.body(size: 12.5, color: squadMuted),
        ),
        action: SquadPrimaryButton(
          label: widget.received ? 'Mark as received' : 'I paid',
          isLoading: saving,
          onPressed: saving ? null : _save,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.received ? 'Got money from $name' : 'Pay $name',
                  style: AppTextStyles.heading(size: 20),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close',
              ),
            ],
          ),
          Text(
            'Buddy balance ${formatMoney(widget.owedCents, ledger.currency)}',
            style: AppTextStyles.body(size: 12.5, color: squadMuted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(ledger.currency.symbol, style: AppTextStyles.heading(size: 28, color: squadMuted)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  key: const ValueKey('buddy-pay-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [MoneyInputFormatter()],
                  style: AppTextStyles.heading(size: 34),
                  decoration: const InputDecoration(hintText: '0', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('HOW', style: AppTextStyles.label(color: squadMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final method in SettlementMethod.values)
                SquadChoiceChip(
                  label: method.label,
                  selected: method == _method,
                  onTap: () => setState(() => _method = method),
                ),
            ],
          ),
          if (!widget.received && _method == SettlementMethod.qr) ...[
            const SizedBox(height: 12),
            if (other?.walletQrPath case final qr?)
              Center(
                child: ClipRRect(
                  borderRadius: AppRadius.md,
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: WalletImage(kind: WalletImageKind.walletQr, path: qr),
                  ),
                ),
              )
            else
              Text(
                "$name hasn't added a payment QR yet.",
                style: AppTextStyles.body(size: 13, color: squadMuted),
              ),
          ],
          if (!widget.received && _method == SettlementMethod.bank) ...[
            const SizedBox(height: 12),
            Text(
              [
                ?other?.bankName,
                ?other?.bankAccountName,
                ?other?.bankAccountNo,
              ].join(' · ').ifEmpty("$name hasn't added bank details yet."),
              style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600),
            ),
          ],
          if (!widget.received && _method != SettlementMethod.cash) ...[
            const SizedBox(height: 12),
            if (_slip case final slip?)
              Row(
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.sm,
                    child: Image.memory(slip.bytes, width: 52, height: 52, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Slip attached')),
                  TextButton(onPressed: () => setState(() => _slip = null), child: const Text('Remove')),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await pickWalletImage(context, slip: true);
                  if (picked != null && mounted) setState(() => _slip = picked);
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Add payment slip (optional)'),
              ),
          ],
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
