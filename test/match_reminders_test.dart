import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/match/domain/entities/match.dart';
import 'package:squad_hq/features/match/domain/entities/matchday_player.dart';
import 'package:squad_hq/features/team/presentation/match_reminders.dart';

void main() {
  final now = DateTime(2026, 9, 24, 12);
  Match match(String id, DateTime kickoff) =>
      Match(id: id, teamId: 't', opponent: 'Kickhub', kickoffAt: kickoff, venue: 'Onnut');

  test('Reminds 2 hours before matches you said In or Maybe to', () {
    final reminders = planMatchReminders(
      upcoming: [
        match('in', DateTime(2026, 9, 27, 20)),
        match('maybe', DateTime(2026, 9, 28, 20)),
        match('out', DateTime(2026, 9, 29, 20)),
        match('no-reply', DateTime(2026, 9, 30, 20)),
      ],
      myAnswers: const {
        'in': RsvpAnswer.yes,
        'maybe': RsvpAnswer.maybe,
        'out': RsvpAnswer.no,
      },
      now: now,
    );

    expect(reminders.map((r) => r.id), [reminderIdFor('in'), reminderIdFor('maybe')]);
    expect(reminders.first.at, DateTime(2026, 9, 27, 18));
    expect(reminders.first.title, 'Match in 2 hours');
    expect(reminders.first.body, 'vs Kickhub at 8:00 PM · Onnut');
    expect(reminders.first.route, '/match');
  });

  test('Skips a match whose reminder time has already passed', () {
    final reminders = planMatchReminders(
      // Kicks off in 90 minutes — the 2-hour mark is gone.
      upcoming: [match('soon', now.add(const Duration(minutes: 90)))],
      myAnswers: const {'soon': RsvpAnswer.yes},
      now: now,
    );
    expect(reminders, isEmpty);
  });

  test('Reminder ids are stable and positive', () {
    expect(reminderIdFor('match-abc'), reminderIdFor('match-abc'));
    expect(reminderIdFor('match-abc'), isNot(reminderIdFor('match-abd')));
    expect(reminderIdFor('3f8e2b1c-0d4a-4e5f-9a6b-7c8d9e0f1a2b'), greaterThan(0));
  });
}
