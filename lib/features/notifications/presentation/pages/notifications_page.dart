import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/entities/app_notification.dart';
import '../bloc/notification_bloc.dart';
import '../notification_navigation.dart';

/// Every notification the player was sent, newest first — opened from
/// Home's bell. Unread ones carry a red dot; tapping one marks it read and
/// opens what it's about; "Read all" clears the bell's count.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.args});

  final NotificationsArgs args;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NotificationBloc, NotificationState>(
      listenWhen: (previous, current) => current.error != null && current.error != previous.error,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error!))),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            foregroundColor: AppColors.text,
            title: Text('Notifications', style: AppTextStyles.heading(size: 16)),
            actions: [
              TextButton(
                onPressed: state.unreadCount == 0
                    ? null
                    : () => context.read<NotificationBloc>().add(const NotificationsAllRead()),
                child: Text(
                  'Read all',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: state.unreadCount == 0
                        ? AppColors.text.withValues(alpha: 0.3)
                        : AppColors.accent700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: !state.loaded
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () {
                    final done = Completer<void>();
                    context.read<NotificationBloc>().add(NotificationsRefreshRequested(done: done));
                    return done.future;
                  },
                  child: state.items.isEmpty
                      ? const _Empty()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: state.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            return _NotificationTile(
                              notification: item,
                              onTap: () => openNotification(
                                context,
                                item,
                                userId: args.userId,
                                adminViewIsManager: args.adminViewIsManager,
                              ),
                            );
                          },
                        ),
                ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  ({IconData icon, String label, String action}) get _style => switch (notification.target) {
        NotificationTarget.match =>
          (icon: Icons.sports_soccer_rounded, label: 'MATCH', action: 'Open match'),
        NotificationTarget.pastMatch =>
          (icon: Icons.emoji_events_rounded, label: 'MAN OF THE MATCH', action: 'See result'),
        NotificationTarget.wallet =>
          (icon: Icons.account_balance_wallet_rounded, label: 'WALLET', action: 'Open wallet'),
        NotificationTarget.settle =>
          (icon: Icons.swap_horiz_rounded, label: 'SETTLE UP', action: 'Open settle up'),
        NotificationTarget.expense =>
          (icon: Icons.chat_bubble_outline_rounded, label: 'COMMENT', action: 'Open expense'),
      };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final style = _style;
    final muted = AppColors.text.withValues(alpha: 0.5);
    return Semantics(
      button: true,
      label: unread ? 'Unread' : null,
      child: Material(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: unread ? AppColors.accent300 : AppColors.text.withValues(alpha: 0.08),
                width: unread ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: unread ? AppColors.accent100 : AppColors.neutral200,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        style.icon,
                        size: 16,
                        color: unread ? AppColors.accent700 : muted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        style.label,
                        style: AppTextStyles.label(
                          color: unread ? AppColors.accent700 : muted,
                        ),
                      ),
                    ),
                    Text(
                      formatNotificationTime(notification.createdAt),
                      style: AppTextStyles.body(size: 11, weight: FontWeight.w600, color: muted),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.unread,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notification.title,
                  style: AppTextStyles.heading(
                    size: 15,
                    height: 1.25,
                    color: AppColors.text.withValues(alpha: unread ? 1 : 0.7),
                  ),
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: AppTextStyles.body(
                      size: 13,
                      color: AppColors.text.withValues(alpha: unread ? 0.65 : 0.5),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      style.action,
                      style: AppTextStyles.body(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: unread ? AppColors.accent700 : muted,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: unread ? AppColors.accent700 : muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    // Scrollable, so pull-to-refresh still works on an empty list.
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 120, 32, 32),
      children: [
        Icon(
          Icons.notifications_none_rounded,
          size: 40,
          color: AppColors.text.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          'No notifications yet',
          textAlign: TextAlign.center,
          style: AppTextStyles.heading(size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'New matches, reminders and payments will show up here.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 13, color: AppColors.text.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

/// "Just now", "5m ago", "3h ago", "2d ago", then the date.
String formatNotificationTime(DateTime at, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(at);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  if (age.inDays < 7) return '${age.inDays}d ago';
  return formatMatchDate(at.toLocal());
}
