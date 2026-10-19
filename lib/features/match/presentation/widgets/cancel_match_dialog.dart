import 'package:flutter/material.dart';

import '../../../wallet/domain/entities/team_wallet.dart';
import '../../../wallet/presentation/wallet_formatting.dart';

/// "Cancel this match? This can't be undone." — always asked before an
/// admin cancels, before or after kickoff. Names the bill and payments
/// that go with it, if there are any. True to go ahead.
Future<bool> confirmCancelMatch(
  BuildContext context, {
  required String opponent,
  WalletMatch? walletMatch,
}) async {
  final bill = walletMatch?.bill;
  final payments = bill?.payments.length ?? 0;
  final billLine = bill == null
      ? ''
      : '\n\nThis also removes the ${formatBaht(bill.totalCost)} bill'
            '${payments == 0 ? '' : ' and $payments ${payments == 1 ? 'payment' : 'payments'}'}.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel this match?'),
      content: Text(
        "This can't be undone. It removes the match vs $opponent with everyone's RSVPs, "
        'game scores, answers and Man of the Match votes.$billLine',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Keep it'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Cancel match'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
