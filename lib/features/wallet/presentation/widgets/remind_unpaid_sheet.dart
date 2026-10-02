import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../wallet_formatting.dart';

/// "Remind unpaid", two ways: everyone who still owes, or players picked one
/// by one. Each player can be reminded once a day per bill — anyone already
/// reminded today is shown but can't be picked (`remind_bill_payment`
/// enforces the same). Reads the bill live from [WalletBloc].
Future<void> showRemindUnpaidSheet(BuildContext context, {required String matchId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RemindUnpaidSheet(matchId: matchId),
  );
}

class _RemindUnpaidSheet extends StatefulWidget {
  const _RemindUnpaidSheet({required this.matchId});

  final String matchId;

  @override
  State<_RemindUnpaidSheet> createState() => _RemindUnpaidSheetState();
}

class _RemindUnpaidSheetState extends State<_RemindUnpaidSheet> {
  final _picked = <String>{};

  void _remind(Set<String>? profileIds) {
    context.read<WalletBloc>().add(
          WalletRemindUnpaidRequested(widget.matchId, profileIds: profileIds),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletBloc, WalletState>(
      listenWhen: (previous, current) =>
          current is WalletFailure || (previous is WalletSubmitting && current is WalletLoaded),
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        if (state case WalletFailure(:final message)) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        messenger.showSnackBar(const SnackBar(content: Text('Reminder sent')));
        Navigator.of(context).pop();
      },
      builder: (context, state) {
        final wallet = state.wallet;
        final walletMatch = wallet?.forMatch(widget.matchId);
        final split = walletMatch == null ? null : wallet?.splitFor(walletMatch);
        if (walletMatch == null || split == null) return const SizedBox(height: 120);
        final bill = split.bill;
        final now = DateTime.now();
        final unpaid = split.unpaid;
        final remindable = [
          for (final share in unpaid)
            if (!bill.remindedToday(share.member.profileId, now)) share.member.profileId,
        ];
        // Drop picks that became un-pickable (paid / reminded meanwhile).
        _picked.retainAll(remindable);
        final busy = state is WalletSubmitting;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            children: [
              Text('Remind unpaid', style: AppTextStyles.heading(size: 18)),
              const SizedBox(height: 4),
              Text(
                'vs ${walletMatch.match.opponent} · ${formatBaht(split.roundedShare)} each · '
                'once a day per player',
                style: AppTextStyles.body(
                  size: 12.5,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: busy || remindable.isEmpty ? null : () => _remind(null),
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(
                    remindable.isEmpty
                        ? 'Everyone was reminded today'
                        : 'Remind all unpaid (${remindable.length})',
                    style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.45),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'OR PICK PLAYERS',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 8),
              Material(
                color: AppColors.neutral100,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    for (final share in unpaid)
                      Builder(
                        builder: (context) {
                          final id = share.member.profileId;
                          final reminded = bill.remindedToday(id, now);
                          return CheckboxListTile(
                            value: reminded || _picked.contains(id),
                            onChanged: reminded || busy
                                ? null
                                : (checked) => setState(() {
                                    checked == true ? _picked.add(id) : _picked.remove(id);
                                  }),
                            title: Text(
                              share.member.name,
                              style: AppTextStyles.body(size: 13.5, weight: FontWeight.w700),
                            ),
                            subtitle: reminded
                                ? Text(
                                    'Reminded today at ${formatMatchTime(bill.remindedAt[id]!)}',
                                    style: AppTextStyles.body(
                                      size: 11.5,
                                      color: AppColors.text.withValues(alpha: 0.5),
                                    ),
                                  )
                                : null,
                            activeColor: AppColors.accent,
                            dense: true,
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: busy || _picked.isEmpty ? null : () => _remind({..._picked}),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    _picked.isEmpty ? 'Pick players to remind' : 'Remind selected (${_picked.length})',
                    style: AppTextStyles.heading(size: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
