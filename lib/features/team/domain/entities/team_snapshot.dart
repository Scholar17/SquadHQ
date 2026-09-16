import 'package:equatable/equatable.dart';

/// "Role switch, not two apps." One toggle at the top swaps manager and
/// player verbs across every tab.
enum SquadRole { manager, player }

/// A player's response to a fixture — pending is a silent no-reply, which
/// is why manager screens distinguish it from an explicit "no".
enum RsvpStatus { yes, maybe, no, pending }

class TeamInfo extends Equatable {
  const TeamInfo({
    required this.name,
    required this.meta,
    required this.initials,
    required this.alertCount,
  });

  final String name;
  final String meta;
  final String initials;
  final int alertCount;

  bool get hasAlerts => alertCount > 0;

  @override
  List<Object?> get props => [name, meta, initials, alertCount];
}

class UpcomingMatch extends Equatable {
  const UpcomingMatch({
    required this.opponent,
    required this.kickoffLabel,
    required this.countdownLabel,
    required this.venueLine,
    required this.confirmedOf,
    required this.feePerPlayer,
    required this.kit,
    required this.temperatureC,
    required this.rainChancePercent,
    required this.rsvpClosesLabel,
    required this.hubLine1,
    required this.hubLine2,
  });

  final String opponent;
  final String kickoffLabel;
  final String countdownLabel;
  final String venueLine;
  final String confirmedOf;
  final String feePerPlayer;
  final String kit;
  final int temperatureC;
  final int rainChancePercent;
  final String rsvpClosesLabel;
  final String hubLine1;
  final String hubLine2;

  @override
  List<Object?> get props => [
        opponent,
        kickoffLabel,
        countdownLabel,
        venueLine,
        confirmedOf,
        feePerPlayer,
        kit,
        temperatureC,
        rainChancePercent,
        rsvpClosesLabel,
        hubLine1,
        hubLine2,
      ];
}

enum NeedsYouKind { vote, wallet, availability }

class NeedsYouItem extends Equatable {
  const NeedsYouItem({
    required this.kind,
    required this.title,
    required this.meta,
  });

  final NeedsYouKind kind;
  final String title;
  final String meta;

  @override
  List<Object?> get props => [kind, title, meta];
}

class MatchResult extends Equatable {
  const MatchResult({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeScore,
    required this.awayScore,
    required this.summary,
  });

  final String homeTeam;
  final String awayTeam;
  final int homeScore;
  final int awayScore;
  final String summary;

  @override
  List<Object?> get props =>
      [homeTeam, awayTeam, homeScore, awayScore, summary];
}

class PlayerStat extends Equatable {
  const PlayerStat({required this.label, required this.value});

  final String label;
  final int value; // 0-99

  @override
  List<Object?> get props => [label, value];
}

class PlayerCard extends Equatable {
  const PlayerCard({
    required this.apps,
    required this.goals,
    required this.assists,
    required this.stats,
  });

  final int apps;
  final int goals;
  final int assists;
  final List<PlayerStat> stats;

  @override
  List<Object?> get props => [apps, goals, assists, stats];
}

class SquadMember extends Equatable {
  const SquadMember({
    required this.id,
    required this.name,
    required this.position,
    required this.number,
    required this.ovr,
    required this.joinedYear,
    required this.seasonLine,
    required this.rsvpStatus,
    required this.amountOwed,
    required this.card,
  });

  final String id;
  final String name;
  final String position;
  final int number;
  final int ovr;
  final int joinedYear;
  final String seasonLine;
  final RsvpStatus rsvpStatus;

  /// In baht; 0 means settled up.
  final double amountOwed;
  final PlayerCard card;

  String get statusLabel => switch (rsvpStatus) {
        RsvpStatus.yes => 'Confirmed',
        RsvpStatus.maybe => 'Maybe',
        RsvpStatus.no => 'Can\'t make it',
        RsvpStatus.pending => 'No reply yet',
      };

  bool get needsNudge => rsvpStatus == RsvpStatus.pending;

  @override
  List<Object?> get props => [
        id,
        name,
        position,
        number,
        ovr,
        joinedYear,
        seasonLine,
        rsvpStatus,
        amountOwed,
        card,
      ];
}

class LedgerEntry extends Equatable {
  const LedgerEntry({
    required this.label,
    required this.meta,
    required this.amount,
    required this.isCredit,
  });

  final String label;
  final String meta;

  /// Formatted, signed amount string, e.g. "+฿1,650" or "-฿800".
  final String amount;
  final bool isCredit;

  @override
  List<Object?> get props => [label, meta, amount, isCredit];
}

class TeamSnapshot extends Equatable {
  const TeamSnapshot({
    required this.team,
    required this.match,
    required this.needsYou,
    required this.lastResult,
    required this.roster,
    required this.teamBalance,
    required this.monthIn,
    required this.monthOut,
    required this.monthNet,
    required this.ledger,
  });

  final TeamInfo team;
  final UpcomingMatch match;
  final List<NeedsYouItem> needsYou;
  final MatchResult lastResult;
  final List<SquadMember> roster;
  final String teamBalance;
  final String monthIn;
  final String monthOut;
  final String monthNet;
  final List<LedgerEntry> ledger;

  int get confirmedCount =>
      roster.where((m) => m.rsvpStatus == RsvpStatus.yes).length;
  int get maybeCount =>
      roster.where((m) => m.rsvpStatus == RsvpStatus.maybe).length;
  int get noReplyCount =>
      roster.where((m) => m.rsvpStatus == RsvpStatus.pending).length;

  List<SquadMember> get owing =>
      roster.where((m) => m.amountOwed > 0).toList(growable: false);

  @override
  List<Object?> get props => [
        team,
        match,
        needsYou,
        lastResult,
        roster,
        teamBalance,
        monthIn,
        monthOut,
        monthNet,
        ledger,
      ];
}
