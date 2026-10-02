import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../../wallet/domain/repositories/wallet_repository.dart';
import '../../../wallet/presentation/widgets/wallet_image.dart';
import '../../domain/entities/settlement.dart';
import '../../domain/entities/squad_ledger.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// The receiver checks a payment sent to them: the slip, amount and
/// method, then "Received" — or "Reject" with a reason, which sends it
/// back so the payer can try again.
Future<void> showConfirmPaymentSheet(BuildContext context, {required Settlement settlement}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.neutral100,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

  /// Which answer was sent, for the snackbar once it's saved.
  bool? _accepted;

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
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _accepted == true
                  ? 'Payment confirmed. Balances are updated.'
                  : 'Sent back to $name — they can send it again.',
            ),
          ),
        );
      },
      builder: (context, state) {
        final ledger = state.ledger ?? SquadLedger.empty;
        final name = ledger.nameOf(settlement.fromId);
        final isSubmitting = state is SquadLedgerSubmitting;
        final slip = settlement.slipPath;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Text('PAYMENT TO CONFIRM', style: AppTextStyles.label(color: squadMuted)),
            const SizedBox(height: 4),
            Text('$name says they paid you', style: AppTextStyles.heading(size: 22, height: 1.2)),
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
                          borderRadius: BorderRadius.circular(14),
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
                      _Fact('Amount', formatMoney(settlement.amountCents, ledger.currency)),
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => setState(() {
                              _rejecting = !_rejecting;
                              _reason = null;
                            }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: AppColors.text.withValues(alpha: 0.2)),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        _rejecting ? 'Cancel' : 'Reject',
                        style: AppTextStyles.body(size: 15, weight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SquadPrimaryButton(
                    label: _rejecting ? 'Send back' : 'Received',
                    color: _rejecting ? AppColors.accent700 : AppColors.accent2_700,
                    isLoading: isSubmitting,
                    onPressed: _rejecting && _reason == null
                        ? null
                        : () => _answer(accept: !_rejecting),
                  ),
                ),
              ],
            ),
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
