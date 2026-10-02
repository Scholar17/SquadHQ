import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notifications/local_notifications.dart';
import '../../match/domain/entities/match.dart';
import '../../match/domain/entities/matchday_player.dart';
import '../../match/presentation/bloc/match_bloc.dart';
import '../../match/presentation/bloc/match_state.dart';
import '../../match/presentation/match_formatting.dart';
import '../../wallet/presentation/bloc/wallet_bloc.dart';
import '../../wallet/presentation/bloc/wallet_state.dart';

/// How long before kick-off the on-device match reminder fires.
const matchReminderLead = Duration(hours: 2);

/// A stable notification id per match (FNV-1a, 31-bit) — `String.hashCode`
/// isn't guaranteed to stay the same between app runs.
int reminderIdFor(String matchId) {
  var hash = 0x811c9dc5;
  for (final unit in matchId.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// A reminder [matchReminderLead] before each upcoming match the player
/// said In or Maybe to — skipping any whose reminder time has passed.
List<ScheduledReminder> planMatchReminders({
  required List<Match> upcoming,
  required Map<String, RsvpAnswer> myAnswers,
  required DateTime now,
}) =>
    [
      for (final match in upcoming)
        if (myAnswers[match.id] case RsvpAnswer.yes || RsvpAnswer.maybe)
          if (match.kickoffAt.subtract(matchReminderLead).isAfter(now))
            ScheduledReminder(
              id: reminderIdFor(match.id),
              at: match.kickoffAt.subtract(matchReminderLead),
              title: 'Match in 2 hours',
              body: [
                'vs ${match.opponent} at ${formatMatchTime(match.kickoffAt)}',
                ?match.venue,
              ].join(' · '),
              route: '/match',
            ),
    ];

/// Keeps the phone's scheduled match reminders in step with the upcoming
/// matches and the player's RSVPs (read from the wallet, which reloads
/// after every RSVP). Android only — LocalNotifications no-ops elsewhere.
class MatchReminderSync extends StatelessWidget {
  const MatchReminderSync({super.key, required this.userId, required this.child});

  final String userId;
  final Widget child;

  void _sync(BuildContext context) {
    final upcoming = switch (context.read<MatchBloc>().state) {
      MatchLoaded(:final matches) => matches,
      _ => null,
    };
    final wallet = context.read<WalletBloc>().state.wallet;
    // Only once both have settled — never cancel reminders mid-load.
    if (upcoming == null || wallet == null) return;
    LocalNotifications.syncReminders(
      planMatchReminders(
        upcoming: upcoming,
        myAnswers: {
          for (final match in upcoming) match.id: ?wallet.forMatch(match.id)?.answers[userId],
        },
        now: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MatchBloc, MatchState>(listener: (context, _) => _sync(context)),
        BlocListener<WalletBloc, WalletState>(listener: (context, _) => _sync(context)),
      ],
      child: child,
    );
  }
}
