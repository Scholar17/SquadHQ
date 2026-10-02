import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/bill_split.dart';
import '../../domain/entities/team_wallet.dart';
import '../../domain/usecases/get_my_wallet_qr.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../wallet_formatting.dart';

/// Add or edit a match's total cost and how it's split. Opened from both
/// the Match tab's bill card and the Wallet tab — the same bill either
/// way. Whoever saves it is recorded as the payer, and `set_match_bill`
/// (supabase/sql/008_match_bills_and_wallet_qr.sql) only lets team admins
/// add one, and only the payer change it after.
///
/// Teammates pay the payer back by scanning their wallet QR, so this first
/// checks the signed-in profile has one — if not, it just says so (with a
/// shortcut to Profile) and doesn't open (`set_match_bill` refuses without
/// one too).
Future<void> showBillSheet(
  BuildContext context, {
  required String matchId,
  required String userId,
}) async {
  final qr = await sl<GetMyWalletQr>()(const NoParams());
  // On a lookup failure (e.g. offline), carry on — the server still checks.
  final hasQr = qr.fold((_) => true, (path) => path != null);
  if (!context.mounted) return;
  if (!hasQr) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Add your wallet QR in Profile first — teammates need it to pay you back.'),
          action: SnackBarAction(
            label: 'Profile',
            onPressed: () => GoRouter.of(context).push(AppRoutes.profile),
          ),
        ),
      );
    return;
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _BillSheet(matchId: matchId, userId: userId),
  );
}

class _BillSheet extends StatefulWidget {
  const _BillSheet({required this.matchId, required this.userId});

  final String matchId;
  final String userId;

  @override
  State<_BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends State<_BillSheet> {
  late final TeamWallet _wallet = context.read<WalletBloc>().state.wallet ?? TeamWallet.empty;
  late final WalletMatch? _walletMatch = _wallet.forMatch(widget.matchId);
  late final MatchBill? _existing = _walletMatch?.bill;

  late final _totalController = TextEditingController(text: _totalText(_existing?.totalCost));
  late SplitMode _mode = _existing?.splitMode ?? SplitMode.rsvpIn;
  late final Set<String> _picked = {...?_existing?.customMemberIds};

  static String? _totalText(double? total) {
    if (total == null) return null;
    return total == total.roundToDouble() ? total.toInt().toString() : total.toStringAsFixed(2);
  }

  double? get _total {
    final total = double.tryParse(_totalController.text.trim().replaceAll(',', ''));
    return total != null && total > 0 ? total : null;
  }

  bool get _isValid => _total != null && (_mode != SplitMode.custom || _picked.isNotEmpty);

  BillSplit get _preview => BillSplit.compute(
        bill: MatchBill(
          totalCost: _total ?? 0,
          payerId: widget.userId,
          payerName: '',
          splitMode: _mode,
          customMemberIds: _picked,
          payments: _existing?.payments ?? const {},
        ),
        members: _wallet.members,
        answers: _walletMatch?.answers ?? const {},
      );

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  void _submit() {
    final total = _total;
    if (!_isValid || total == null) return;
    context.read<WalletBloc>().add(
          WalletBillSaveRequested(
            matchId: widget.matchId,
            totalCost: total,
            splitMode: _mode,
            memberIds: _mode == SplitMode.custom ? {..._picked} : const {},
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final match = _walletMatch?.match;
    final preview = _preview;
    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) =>
          current is WalletFailure || (previous is WalletSubmitting && current is WalletLoaded),
      listener: (context, state) {
        if (state case WalletFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        Navigator.of(context).pop();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                _existing == null ? 'Add total cost' : 'Edit bill',
                style: AppTextStyles.heading(size: 18),
              ),
              if (match != null) ...[
                const SizedBox(height: 4),
                Text(
                  'vs ${match.opponent}',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.text.withValues(alpha: 0.55),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: TextField(
                  controller: _totalController,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  decoration: InputDecoration(
                    hintText: 'Total cost you paid',
                    prefixText: '฿ ',
                    filled: true,
                    fillColor: AppColors.neutral100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'SPLIT BETWEEN',
                style: AppTextStyles.label(color: AppColors.text.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in SplitMode.values)
                    ChoiceChip(
                      label: Text(splitModeLabel(mode)),
                      selected: _mode == mode,
                      onSelected: (_) => setState(() => _mode = mode),
                      selectedColor: AppColors.neutral900,
                      labelStyle: AppTextStyles.body(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: _mode == mode ? AppColors.neutral100 : AppColors.text,
                      ),
                      showCheckmark: false,
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
              if (_mode == SplitMode.custom) ...[
                const SizedBox(height: 10),
                // A Material (not a decorated Container) so the list tiles'
                // tap ripples paint on it rather than underneath.
                Material(
                  color: AppColors.neutral100,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: AppColors.text.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      for (final member in _wallet.members)
                        CheckboxListTile(
                          value: _picked.contains(member.profileId),
                          onChanged: (checked) => setState(() {
                            checked == true
                                ? _picked.add(member.profileId)
                                : _picked.remove(member.profileId);
                          }),
                          title: Text(
                            member.profileId == widget.userId ? '${member.name} (you)' : member.name,
                            style: AppTextStyles.body(size: 13, weight: FontWeight.w700),
                          ),
                          activeColor: AppColors.accent,
                          dense: true,
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _SplitPreview(split: preview, mode: _mode, hasTotal: _total != null),
              const SizedBox(height: 12),
              Text(
                "You'll be shown as the one who paid, with your wallet QR from "
                'your profile. Only you can change this bill after saving.',
                style: AppTextStyles.body(
                  size: 11.5,
                  color: AppColors.text.withValues(alpha: 0.55),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              BlocBuilder<WalletBloc, WalletState>(
                builder: (context, state) {
                  final isSubmitting = state is WalletSubmitting;
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting || !_isValid ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.bg,
                        disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.bg,
                              ),
                            )
                          : Text(
                              'Save bill',
                              style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitPreview extends StatelessWidget {
  const _SplitPreview({required this.split, required this.mode, required this.hasTotal});

  final BillSplit split;
  final SplitMode mode;
  final bool hasTotal;

  @override
  Widget build(BuildContext context) {
    final count = split.shares.length;
    final String message;
    if (count == 0) {
      message = switch (mode) {
        SplitMode.rsvpIn => "No one has said In yet — the split updates as they RSVP.",
        SplitMode.custom => 'Pick at least one player.',
        SplitMode.team => 'This team has no members yet.',
      };
    } else if (!hasTotal) {
      message = 'Enter the total to see each share.';
    } else {
      message = '';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: message.isNotEmpty
          ? Text(
              message,
              style: AppTextStyles.body(
                size: 12.5,
                weight: FontWeight.w500,
                color: AppColors.text.withValues(alpha: 0.6),
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '$count ${count == 1 ? 'player' : 'players'} · each pays',
                    style: AppTextStyles.body(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.text.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                ShareAmount(split: split),
              ],
            ),
    );
  }
}

/// A share with the rounded-up amount in large type and the exact amount
/// in small type underneath, e.g. "฿334" over "exact ฿333.33".
class ShareAmount extends StatelessWidget {
  const ShareAmount({
    super.key,
    required this.split,
    this.size = 26,
    this.color,
    this.crossAxisAlignment = CrossAxisAlignment.end,
  });

  final BillSplit split;
  final double size;
  final Color? color;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.text;
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatBaht(split.roundedShare), style: AppTextStyles.heading(size: size, color: color)),
        Text(
          'exact ${formatBahtExact(split.exactShare)}',
          style: AppTextStyles.body(
            size: 10.5,
            weight: FontWeight.w600,
            color: color.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}
