import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../bloc/wallet_bloc.dart';
import '../bloc/wallet_event.dart';
import '../bloc/wallet_state.dart';
import '../wallet_formatting.dart';
import 'bill_sheet.dart';
import 'wallet_image.dart';
import 'wallet_image_actions.dart';

/// Pay back a bill's payer: their wallet QR (view or save it), then
/// upload a payment slip screenshot as proof. Reads the bill live from
/// [WalletBloc], so it flips to "paid" as soon as the slip is in.
Future<void> showPayBillSheet(
  BuildContext context, {
  required String matchId,
  required String userId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _PayBillSheet(matchId: matchId, userId: userId),
  );
}

class _PayBillSheet extends StatelessWidget {
  const _PayBillSheet({required this.matchId, required this.userId});

  final String matchId;
  final String userId;

  Future<void> _uploadSlip(BuildContext context) async {
    final picked = await pickWalletImage();
    if (picked == null || !context.mounted) return;
    context.read<WalletBloc>().add(
          WalletPaymentSubmitted(
            matchId: matchId,
            slipBytes: picked.bytes,
            fileExtension: picked.fileExtension,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WalletBloc, WalletState>(
      listenWhen: (previous, current) => current is WalletFailure,
      listener: (context, state) {
        if (state case WalletFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        }
      },
      builder: (context, state) {
        final wallet = state.wallet;
        final walletMatch = wallet?.forMatch(matchId);
        final split = walletMatch == null ? null : wallet?.splitFor(walletMatch);
        final share = split?.shareFor(userId);
        if (walletMatch == null || split == null || share == null) {
          return Padding(
            padding: const EdgeInsets.all(28),
            child: Text(
              "You're not part of this bill.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
            ),
          );
        }
        final bill = split.bill;
        final qrPath = bill.payerQrPath;
        final payment = share.payment;
        final isSubmitting = state is WalletSubmitting;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Text(
                'Pay ${bill.payerName}',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading(size: 22),
              ),
              const SizedBox(height: 4),
              Text(
                'Your share for vs ${walletMatch.match.opponent} · '
                '${formatMatchDate(walletMatch.match.kickoffAt)}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  size: 12.5,
                  weight: FontWeight.w500,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: ShareAmount(
                  split: split,
                  size: 36,
                  color: AppColors.accent700,
                  crossAxisAlignment: CrossAxisAlignment.center,
                ),
              ),
              const SizedBox(height: 18),
              if (qrPath == null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    "${bill.payerName} hasn't added a wallet QR to their profile yet. "
                    'Ask them how to pay, then upload your slip here.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      size: 12.5,
                      color: AppColors.text.withValues(alpha: 0.65),
                      height: 1.5,
                    ),
                  ),
                )
              else ...[
                Center(
                  child: GestureDetector(
                    onTap: () => showWalletImageViewer(
                      context,
                      kind: WalletImageKind.walletQr,
                      path: qrPath,
                      title: "${bill.payerName}'s wallet QR",
                    ),
                    child: Container(
                      width: 220,
                      height: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
                      ),
                      child: WalletImage(kind: WalletImageKind.walletQr, path: qrPath),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () => saveWalletQr(context, qrPath),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text('Save QR', style: AppTextStyles.heading(size: 13)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.text),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (payment != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent2_100,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.accent2_700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Paid · slip sent ${formatMatchDate(payment.paidAt)}',
                          style: AppTextStyles.body(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.accent2_900,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => showWalletImageViewer(
                          context,
                          kind: WalletImageKind.paymentSlip,
                          path: payment.slipPath,
                          title: 'Your payment slip',
                        ),
                        child: Text(
                          'View slip',
                          style: AppTextStyles.heading(size: 12, color: AppColors.accent2_900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: payment == null
                    ? ElevatedButton.icon(
                        onPressed: isSubmitting ? null : () => _uploadSlip(context),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.bg,
                                ),
                              )
                            : const Icon(Icons.upload_rounded),
                        label: Text(
                          "I've paid — upload slip",
                          style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                      )
                    : OutlinedButton(
                        onPressed: isSubmitting ? null : () => _uploadSlip(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                          shape: const StadiumBorder(),
                        ),
                        child: Text('Replace slip', style: AppTextStyles.heading(size: 14)),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                'Total ${formatBahtExact(bill.totalCost)} · ${splitModeLabel(bill.splitMode)} '
                '(${split.shares.length})',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  size: 11.5,
                  color: AppColors.text.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
