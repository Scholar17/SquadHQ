import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'push_notifications.dart';

/// Asked once per visit, right after sign-in.
bool _askedThisVisit = false;

/// Web, just signed in (or opened signed in): "Turn on notifications?"
/// once per visit, while they've never been asked. The Turn on tap is what
/// lets the browser show its permission prompt. Not now just closes it —
/// Profile → Notifications still offers it (and explains blocked and the
/// iPhone Home Screen rule).
Future<void> askToTurnOnPush(BuildContext context) async {
  if (!kIsWeb || _askedThisVisit) return;
  if (await PushNotifications.status() != PushStatus.notAsked) return;
  if (!context.mounted) return;
  _askedThisVisit = true;
  final turnOn = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      title: Text('Turn on notifications?', style: AppTextStyles.heading(size: 20)),
      content: Text(
        'New matches, RSVP and match reminders, Man of the Match and match fees.',
        style: AppTextStyles.body(size: 13.5, color: AppColors.textSubtle),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            'Not now',
            style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: AppColors.text),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Turn on',
            style: AppTextStyles.body(
              size: 14,
              weight: FontWeight.w700,
              color: AppColors.accent700,
            ),
          ),
        ),
      ],
    ),
  );
  if (turnOn == true) await PushNotifications.enable();
}
