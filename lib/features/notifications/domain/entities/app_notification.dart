import 'package:equatable/equatable.dart';

/// What a notification is about — the `<kind>` prefix of its push key in
/// supabase/sql/017_pick_unpaid_reminders.sql's due_push_notifications(),
/// or 024_squads.sql's due_squad_push_notifications().
enum NotificationKind {
  newMatch('new_match'),
  rsvpNudge('rsvp_nudge'),
  reminder('reminder'),
  manualNudge('manual_nudge'),
  squadReady('squad_ready'),
  dropout('dropout'),
  allAnswered('all_answered'),
  digest('digest'),
  motmVote('motm_vote'),
  motmResult('motm_result'),
  feeDue('fee_due'),
  slip('slip'),
  payReminder('pay_reminder'),
  settlePending('settle_pending'),
  settleConfirmed('settle_confirmed'),
  settleRejected('settle_rejected'),
  expenseComment('expense_comment'),
  commentReply('comment_reply'),
  other('');

  const NotificationKind(this.dbName);

  final String dbName;

  static NotificationKind fromDb(String value) =>
      values.firstWhere((kind) => kind.dbName == value, orElse: () => other);
}

/// Where tapping a notification goes.
enum NotificationTarget {
  /// The match's detail screen (RSVP poll, squad, bill) while it's
  /// upcoming; its past-match screen once played.
  match,

  /// The match's past-match screen (score, Man of the Match).
  pastMatch,

  wallet,

  /// A squad's Settle tab (payments to confirm, or yours answered).
  settle,

  /// A squad expense's detail screen (comments and replies).
  expense,
}

/// One entry in the player's notification list — a push that was sent to
/// them (see supabase/sql/022_notification_inbox.sql).
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.matchId,
    this.expenseId,
    this.teamId,
    this.readAt,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? matchId;

  /// The squad expense a comment notification is about.
  final String? expenseId;
  final String? teamId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  NotificationTarget get target => switch (kind) {
        NotificationKind.motmVote || NotificationKind.motmResult => NotificationTarget.pastMatch,
        NotificationKind.feeDue ||
        NotificationKind.slip ||
        NotificationKind.payReminder =>
          NotificationTarget.wallet,
        NotificationKind.settlePending ||
        NotificationKind.settleConfirmed ||
        NotificationKind.settleRejected =>
          NotificationTarget.settle,
        NotificationKind.expenseComment || NotificationKind.commentReply =>
          NotificationTarget.expense,
        _ => NotificationTarget.match,
      };

  AppNotification markedRead(DateTime at) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        matchId: matchId,
        expenseId: expenseId,
        teamId: teamId,
        readAt: readAt ?? at,
      );

  @override
  List<Object?> get props =>
      [id, kind, title, body, createdAt, matchId, expenseId, teamId, readAt];
}
