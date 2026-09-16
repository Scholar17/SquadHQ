import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// A mock PromptPay-style QR sheet — visual only, no real QR payload.
/// Stands in for the design's "Thai QR payment" flow.
Future<void> showPayQrSheet(
  BuildContext context, {
  required String amount,
  required String note,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Scan to pay', style: AppTextStyles.heading(size: 22)),
            const SizedBox(height: 4),
            Text(
              note,
              style: AppTextStyles.body(
                size: 12.5,
                color: AppColors.text.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.text.withValues(alpha: 0.1)),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 150,
                color: AppColors.text.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 20),
            Text(amount, style: AppTextStyles.heading(size: 30, color: AppColors.accent)),
            const SizedBox(height: 4),
            Text(
              'PromptPay · Golden Goal FC',
              style: AppTextStyles.body(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.text.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.bg,
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: Text("I've paid", style: AppTextStyles.heading(size: 14, color: AppColors.bg)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
