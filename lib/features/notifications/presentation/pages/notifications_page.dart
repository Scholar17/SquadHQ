import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../match/presentation/match_formatting.dart';
import '../../domain/entities/app_notification.dart';
import '../bloc/notification_bloc.dart';
import '../notification_navigation.dart';

/// Every notification the player was sent, newest first — opened from
/// Home's bell. Unread ones carry a red dot and sit under "NEW"; tapping
/// one (or swiping it right) marks it read; "Read all" clears the bell's
/// count. Chips filter by what they're about.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.args});

  final NotificationsArgs args;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

/// The filter chips, by what a notification opens.
enum _Filter {
  all('All', {}),
  payments('Payments', {NotificationTarget.wallet, NotificationTarget.settle}),
  expenses('Expenses', {NotificationTarget.expense}),
  matches('Matches', {NotificationTarget.match, NotificationTarget.pastMatch});

  const _Filter(this.label, this.targets);

  final String label;
  final Set<NotificationTarget> targets;

  bool includes(AppNotification n) => this == all || targets.contains(n.target);
}

class _NotificationsPageState extends State<NotificationsPage> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return BlocConsumer<NotificationBloc, NotificationState>(
      listenWhen: (previous, current) => current.error != null && current.error != previous.error,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.error!))),
      builder: (context, state) {
        final items = state.items.where(_filter.includes).toList();
        // Unread first under "NEW", the rest under "EARLIER" — headers only
        // when both exist.
        final unread = items.where((n) => !n.isRead).toList();
        final read = items.where((n) => n.isRead).toList();
        final grouped = unread.isNotEmpty && read.isNotEmpty;
        final rows = <Object>[
          if (grouped) 'NEW · ${unread.length}',
          ...unread,
          if (grouped) 'EARLIER',
          ...read,
        ];
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            elevation: 0,
            foregroundColor: AppColors.text,
            title: Text('Notifications', style: AppTextStyles.title(size: 16)),
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
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                          itemCount: rows.length + 1 + (rows.isEmpty ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _FilterRow(
                                selected: _filter,
                                onSelected: (filter) => setState(() => _filter = filter),
                              );
                            }
                            if (rows.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 48),
                                child: Text(
                                  'No ${_filter.label.toLowerCase()} notifications.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.body(size: 13, color: AppColors.neutral700),
                                ),
                              );
                            }
                            return switch (rows[index - 1]) {
                              final String header => Padding(
                                padding: EdgeInsets.only(top: index == 1 ? 4 : 14, bottom: 10),
                                child: Text(
                                  header,
                                  style: AppTextStyles.label(color: AppColors.neutral700),
                                ),
                              ),
                              final AppNotification item => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _SwipeToRead(
                                  notification: item,
                                  child: _NotificationTile(
                                    notification: item,
                                    onTap: () => openNotification(
                                      context,
                                      item,
                                      userId: args.userId,
                                    ),
                                  ),
                                ),
                              ),
                              _ => const SizedBox.shrink(),
                            };
                          },
                        ),
                ),
        );
      },
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onSelected});

  final _Filter selected;
  final ValueChanged<_Filter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (final filter in _Filter.values) ...[
            ChoiceChip(
              label: Text(filter.label),
              selected: filter == selected,
              onSelected: (_) => onSelected(filter),
              showCheckmark: false,
              selectedColor: AppColors.neutral900,
              backgroundColor: AppColors.card,
              labelStyle: AppTextStyles.body(
                size: 13,
                weight: FontWeight.w700,
                color: filter == selected ? AppColors.onDark : AppColors.text,
              ),
              side: BorderSide(
                color: filter == selected
                    ? AppColors.neutral900
                    : AppColors.text.withValues(alpha: 0.14),
              ),
              shape: const StadiumBorder(),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Swipe an unread notification right to mark it read without opening
/// it; it stays in the list. Read ones don't swipe.
class _SwipeToRead extends StatelessWidget {
  const _SwipeToRead({required this.notification, required this.child});

  final AppNotification notification;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (notification.isRead) return child;
    return Dismissible(
      key: ValueKey('read-${notification.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        context.read<NotificationBloc>().add(NotificationOpened(notification.id));
        return false;
      },
      background: Container(
        padding: const EdgeInsets.only(left: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: AppColors.accent2_100, borderRadius: AppRadius.lg),
        child: Row(
          children: [
            Icon(Icons.done_all_rounded, size: 20, color: AppColors.accent2_700),
            const SizedBox(width: 8),
            Text(
              'Mark read',
              style: AppTextStyles.body(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.accent2_900,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  ({IconData icon, String label, String action}) get _style => switch (notification.target) {
    NotificationTarget.match when notification.isMatchComment => (
      icon: Icons.chat_bubble_outline_rounded,
      label: 'MATCH CHAT',
      action: 'Open match',
    ),
    NotificationTarget.wallet when notification.isMatchComment => (
      icon: Icons.chat_bubble_outline_rounded,
      label: 'BILL COMMENT',
      action: 'Open wallet',
    ),
    NotificationTarget.match => (
      icon: Icons.sports_soccer_rounded,
      label: 'MATCH',
      action: 'Open match',
    ),
    NotificationTarget.pastMatch => (
      icon: Icons.emoji_events_rounded,
      label: 'MAN OF THE MATCH',
      action: 'See result',
    ),
    NotificationTarget.wallet => (
      icon: Icons.account_balance_wallet_rounded,
      label: 'WALLET',
      action: 'Open wallet',
    ),
    NotificationTarget.settle => (
      icon: Icons.swap_horiz_rounded,
      label: 'SETTLE UP',
      action: 'Open settle up',
    ),
    NotificationTarget.expense when notification.kind == NotificationKind.expenseAdded => (
      icon: Icons.receipt_long_rounded,
      label: 'NEW EXPENSE',
      action: 'Open expense',
    ),
    NotificationTarget.expense => (
      icon: Icons.chat_bubble_outline_rounded,
      label: 'COMMENT',
      action: 'Open expense',
    ),
    NotificationTarget.trip => (icon: Icons.luggage_outlined, label: 'TRIP', action: 'Open trip'),
    NotificationTarget.squad => (
      icon: Icons.star_rounded,
      label: 'PLAYER RATING',
      action: 'Open squad',
    ),
    NotificationTarget.group => (
      icon: Icons.group_remove_outlined,
      label: 'GROUP',
      action: 'Open',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final style = _style;
    // Solid, not translucent: stays legible (~6:1) on the card.
    final muted = AppColors.neutral700;
    return Semantics(
      button: true,
      label: unread ? 'Unread' : null,
      child: Material(
        color: AppColors.card,
        borderRadius: AppRadius.lg,
        child: InkWell(
          borderRadius: AppRadius.lg,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lg,
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
                        style: AppTextStyles.label(color: unread ? AppColors.accent700 : muted),
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
                  style: AppTextStyles.title(
                    size: 15,
                    height: 1.25,
                    color: AppColors.text.withValues(alpha: unread ? 1 : 0.7),
                  ),
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    // The full text is one tap away, on what it's about.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      size: 13,
                      color: AppColors.text.withValues(alpha: unread ? 0.7 : 0.6),
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
          style: AppTextStyles.title(size: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'New matches, reminders and payments will show up here.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(size: 13, color: AppColors.textMuted),
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
