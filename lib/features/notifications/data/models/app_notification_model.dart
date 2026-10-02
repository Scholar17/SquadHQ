import '../../domain/entities/app_notification.dart';

abstract final class AppNotificationModel {
  /// From a `notifications` row.
  static AppNotification fromRow(Map<String, dynamic> row) => AppNotification(
        id: row['id'] as String,
        kind: NotificationKind.fromDb(row['kind'] as String),
        title: row['title'] as String,
        body: row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        matchId: row['match_id'] as String?,
        expenseId: row['expense_id'] as String?,
        teamId: row['team_id'] as String?,
        readAt: switch (row['read_at']) {
          final String at => DateTime.parse(at),
          _ => null,
        },
      );
}
