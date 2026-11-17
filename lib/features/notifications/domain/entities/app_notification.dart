import 'package:equatable/equatable.dart';

/// What a notification is about — the `<kind>` prefix of its push key in
/// supabase/sql/017_pick_unpaid_reminders.sql's due_push_notifications(),
/// due_squad_push_notifications() (latest: 028_expense_added.sql), or
/// due_match_comment_push_notifications() (043_match_comments.sql), or
/// due_rating_push_notifications() (045_player_ratings.sql), or
/// due_mention_push_notifications() (049_mentions.sql), or
/// due_member_removed_push_notifications() (051_leave_and_remove_members.sql), or
/// due_match_question_push_notifications() (053_match_questions.sql), or
/// due_share_push_notifications() (055_share_pushes.sql), or
/// due_group_invite_push_notifications() (056_group_invites.sql).
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
  squadReminder('squad_reminder'),
  monthEnd('month_end'),
  settleNudge('settle_nudge'),
  expenseAdded('expense_added'),
  tripAdded('trip_added'),
  tripClosed('trip_closed'),

  /// "Settle up for `<trip>`" — a squad reminder about one trip (035/036).
  tripReminder('trip_reminder'),
  monthlyDue('monthly_due'),
  matchComment('match_comment'),
  matchReply('match_reply'),
  billComment('bill_comment'),
  billReply('bill_reply'),
  settleRecorded('settle_recorded'),
  promiseMade('promise_made'),
  promiseDue('promise_due'),
  playerRated('player_rated'),
  ratingImproved('rating_improved'),

  /// "Aung Ko mentioned you" — in a comment on a match, a bill or an
  /// expense (049).
  matchMention('match_mention'),
  billMention('bill_mention'),
  expenseMention('expense_mention'),

  /// "You were removed from `<group>`" (051).
  memberRemoved('member_removed'),

  /// "Vote MOTM and rate your game" 2 hours after a match, and "Last day
  /// to rate your game" (053).
  matchFollowup('match_followup'),
  questionsLastDay('questions_last_day'),

  /// "Aung Ko shared the match vs Red Lions" — or its bill (055).
  matchShared('match_shared'),
  billShared('bill_shared'),

  /// "Aung Ko invited you to Sunday FC" (056).
  groupInvite('group_invite'),
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

  /// A squad trip's page (you're on it; it closed for settling up).
  trip,

  /// The team's Squad tab (a teammate rated themselves or levelled up).
  squad,

  /// The group itself (you were removed from it): Home, in it if you've
  /// rejoined since.
  group,

  /// Your Invitations screen (invited to a team or squad).
  invitations,
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
    this.tripId,
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

  /// The squad trip it's about (034_trip_notifications.sql).
  final String? tripId;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  /// A comment, reply or mention on a football match or its bill.
  bool get isMatchComment => switch (kind) {
    NotificationKind.matchComment ||
    NotificationKind.matchReply ||
    NotificationKind.matchMention ||
    NotificationKind.billComment ||
    NotificationKind.billReply ||
    NotificationKind.billMention => true,
    _ => false,
  };

  NotificationTarget get target => switch (kind) {
    NotificationKind.motmVote ||
    NotificationKind.motmResult ||
    NotificationKind.matchFollowup ||
    NotificationKind.questionsLastDay => NotificationTarget.pastMatch,
    NotificationKind.feeDue ||
    NotificationKind.slip ||
    NotificationKind.payReminder ||
    NotificationKind.billComment ||
    NotificationKind.billReply ||
    NotificationKind.billMention ||
    NotificationKind.billShared => NotificationTarget.wallet,
    NotificationKind.settlePending ||
    NotificationKind.settleConfirmed ||
    NotificationKind.settleRejected ||
    NotificationKind.squadReminder ||
    NotificationKind.monthEnd ||
    NotificationKind.settleNudge ||
    NotificationKind.monthlyDue ||
    NotificationKind.settleRecorded ||
    NotificationKind.promiseMade ||
    NotificationKind.promiseDue => NotificationTarget.settle,
    NotificationKind.expenseAdded ||
    NotificationKind.expenseComment ||
    NotificationKind.commentReply ||
    NotificationKind.expenseMention => NotificationTarget.expense,
    NotificationKind.tripAdded ||
    NotificationKind.tripClosed ||
    NotificationKind.tripReminder => NotificationTarget.trip,
    NotificationKind.playerRated ||
    NotificationKind.ratingImproved => NotificationTarget.squad,
    NotificationKind.memberRemoved => NotificationTarget.group,
    NotificationKind.groupInvite => NotificationTarget.invitations,
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
    tripId: tripId,
    readAt: readAt ?? at,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    title,
    body,
    createdAt,
    matchId,
    expenseId,
    teamId,
    tripId,
    readAt,
  ];
}
