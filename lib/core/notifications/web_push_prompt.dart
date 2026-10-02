import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'push_notifications.dart';

/// Home's "turn on notifications" card for the web app. Browsers only let a
/// tap ask for permission, so the web can't prompt on its own the way
/// Android does — this is that tap. On an iPhone/iPad browser tab it
/// explains Add to Home Screen instead (Apple only allows web push for
/// Home Screen apps). Hidden once notifications are on, or when dismissed.
class WebPushPrompt extends StatefulWidget {
  const WebPushPrompt({super.key});

  @override
  State<WebPushPrompt> createState() => _WebPushPromptState();
}

class _WebPushPromptState extends State<WebPushPrompt> {
  /// Dismissed for this visit — it comes back next time the app opens.
  static bool _dismissed = false;

  late Future<PushStatus> _status = PushNotifications.status();
  bool _busy = false;

  Future<void> _turnOn() async {
    setState(() => _busy = true);
    await PushNotifications.enable();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = PushNotifications.status();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _dismissed) return const SizedBox.shrink();
    return FutureBuilder<PushStatus>(
      future: _status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final (IconData icon, String title, String body)? content = switch (status) {
          PushStatus.needsHomeScreen => (
              Icons.ios_share_rounded,
              'Get notifications on your iPhone',
              'Tap Share, then "Add to Home Screen", and open Squad HQ from your Home '
                  'Screen — iPhones only allow notifications there.',
            ),
          PushStatus.notAsked => (
              Icons.notifications_active_rounded,
              'Turn on notifications',
              'New matches, match reminders, Man of the Match and match fees.',
            ),
          PushStatus.blocked => (
              Icons.notifications_off_rounded,
              'Notifications are blocked',
              "Allow them for this site in your browser's settings (the icon next to "
                  'the address), then come back.',
            ),
          _ => null,
        };
        if (content == null) return const SizedBox.shrink();
        final (icon, title, body) = content;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          decoration: BoxDecoration(
            color: AppColors.accent100,
            border: Border.all(color: AppColors.accent700.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.accent700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.body(size: 14, weight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: AppTextStyles.body(
                        size: 12,
                        color: AppColors.text.withValues(alpha: 0.65),
                        height: 1.4,
                      ),
                    ),
                    if (status == PushStatus.notAsked) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _busy ? null : _turnOn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.bg,
                          shape: const StadiumBorder(),
                          elevation: 0,
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          _busy ? 'Turning on…' : 'Turn on',
                          style: AppTextStyles.heading(size: 13, color: AppColors.bg),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _dismissed = true),
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss',
                color: AppColors.text.withValues(alpha: 0.5),
              ),
            ],
          ),
        );
      },
    );
  }
}
