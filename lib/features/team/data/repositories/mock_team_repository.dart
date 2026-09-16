import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/team_snapshot.dart';
import '../../domain/repositories/team_repository.dart';

/// Hardcoded data standing in for the real backend — swap this for a
/// Supabase-backed implementation of [TeamRepository] later; nothing above
/// the repository boundary needs to change.
class MockTeamRepository implements TeamRepository {
  const MockTeamRepository();

  static const _roster = [
    SquadMember(
      id: 'messi',
      name: 'Messi',
      position: 'Forward',
      number: 10,
      ovr: 91,
      joinedYear: 2024,
      seasonLine: '14 apps · 11 goals',
      rsvpStatus: RsvpStatus.yes,
      amountOwed: 0,
      card: PlayerCard(
        apps: 14,
        goals: 11,
        assists: 6,
        stats: [
          PlayerStat(label: 'Pace', value: 85),
          PlayerStat(label: 'Shooting', value: 92),
          PlayerStat(label: 'Passing', value: 91),
          PlayerStat(label: 'Dribbling', value: 96),
          PlayerStat(label: 'Defending', value: 38),
          PlayerStat(label: 'Physical', value: 66),
        ],
      ),
    ),
    SquadMember(
      id: 'ronaldinho',
      name: 'Ronaldinho',
      position: 'Midfielder',
      number: 7,
      ovr: 88,
      joinedYear: 2024,
      seasonLine: '13 apps · 6 goals',
      rsvpStatus: RsvpStatus.yes,
      amountOwed: 0,
      card: PlayerCard(
        apps: 13,
        goals: 6,
        assists: 9,
        stats: [
          PlayerStat(label: 'Pace', value: 80),
          PlayerStat(label: 'Shooting', value: 84),
          PlayerStat(label: 'Passing', value: 89),
          PlayerStat(label: 'Dribbling', value: 95),
          PlayerStat(label: 'Defending', value: 42),
          PlayerStat(label: 'Physical', value: 70),
        ],
      ),
    ),
    SquadMember(
      id: 'kaka',
      name: 'Kaká',
      position: 'Midfielder',
      number: 8,
      ovr: 86,
      joinedYear: 2024,
      seasonLine: '10 apps · 5 goals',
      rsvpStatus: RsvpStatus.maybe,
      amountOwed: 150,
      card: PlayerCard(
        apps: 10,
        goals: 5,
        assists: 4,
        stats: [
          PlayerStat(label: 'Pace', value: 82),
          PlayerStat(label: 'Shooting', value: 80),
          PlayerStat(label: 'Passing', value: 85),
          PlayerStat(label: 'Dribbling', value: 83),
          PlayerStat(label: 'Defending', value: 50),
          PlayerStat(label: 'Physical', value: 73),
        ],
      ),
    ),
    SquadMember(
      id: 'pato',
      name: 'Pato',
      position: 'Forward',
      number: 9,
      ovr: 84,
      joinedYear: 2025,
      seasonLine: '8 apps · 7 goals',
      rsvpStatus: RsvpStatus.no,
      amountOwed: 150,
      card: PlayerCard(
        apps: 8,
        goals: 7,
        assists: 2,
        stats: [
          PlayerStat(label: 'Pace', value: 90),
          PlayerStat(label: 'Shooting', value: 83),
          PlayerStat(label: 'Passing', value: 68),
          PlayerStat(label: 'Dribbling', value: 78),
          PlayerStat(label: 'Defending', value: 30),
          PlayerStat(label: 'Physical', value: 71),
        ],
      ),
    ),
    SquadMember(
      id: 'neymar',
      name: 'Neymar',
      position: 'Forward',
      number: 11,
      ovr: 90,
      joinedYear: 2024,
      seasonLine: '12 apps · 9 goals',
      rsvpStatus: RsvpStatus.yes,
      amountOwed: 0,
      card: PlayerCard(
        apps: 12,
        goals: 9,
        assists: 8,
        stats: [
          PlayerStat(label: 'Pace', value: 91),
          PlayerStat(label: 'Shooting', value: 87),
          PlayerStat(label: 'Passing', value: 86),
          PlayerStat(label: 'Dribbling', value: 94),
          PlayerStat(label: 'Defending', value: 34),
          PlayerStat(label: 'Physical', value: 62),
        ],
      ),
    ),
    SquadMember(
      id: 'casemiro',
      name: 'Casemiro',
      position: 'Defender',
      number: 5,
      ovr: 85,
      joinedYear: 2025,
      seasonLine: '14 apps · 1 goal',
      rsvpStatus: RsvpStatus.pending,
      amountOwed: 150,
      card: PlayerCard(
        apps: 14,
        goals: 1,
        assists: 2,
        stats: [
          PlayerStat(label: 'Pace', value: 65),
          PlayerStat(label: 'Shooting', value: 58),
          PlayerStat(label: 'Passing', value: 78),
          PlayerStat(label: 'Dribbling', value: 68),
          PlayerStat(label: 'Defending', value: 89),
          PlayerStat(label: 'Physical', value: 86),
        ],
      ),
    ),
    SquadMember(
      id: 'marcelo',
      name: 'Marcelo',
      position: 'Defender',
      number: 6,
      ovr: 83,
      joinedYear: 2024,
      seasonLine: '11 apps · 0 goals',
      rsvpStatus: RsvpStatus.yes,
      amountOwed: 0,
      card: PlayerCard(
        apps: 11,
        goals: 0,
        assists: 5,
        stats: [
          PlayerStat(label: 'Pace', value: 87),
          PlayerStat(label: 'Shooting', value: 62),
          PlayerStat(label: 'Passing', value: 82),
          PlayerStat(label: 'Dribbling', value: 85),
          PlayerStat(label: 'Defending', value: 78),
          PlayerStat(label: 'Physical', value: 68),
        ],
      ),
    ),
    SquadMember(
      id: 'coutinho',
      name: 'Coutinho',
      position: 'Midfielder',
      number: 14,
      ovr: 82,
      joinedYear: 2025,
      seasonLine: '9 apps · 4 goals',
      rsvpStatus: RsvpStatus.pending,
      amountOwed: 0,
      card: PlayerCard(
        apps: 9,
        goals: 4,
        assists: 3,
        stats: [
          PlayerStat(label: 'Pace', value: 76),
          PlayerStat(label: 'Shooting', value: 79),
          PlayerStat(label: 'Passing', value: 83),
          PlayerStat(label: 'Dribbling', value: 84),
          PlayerStat(label: 'Defending', value: 45),
          PlayerStat(label: 'Physical', value: 63),
        ],
      ),
    ),
    SquadMember(
      id: 'fernandinho',
      name: 'Fernandinho',
      position: 'Goalkeeper',
      number: 1,
      ovr: 80,
      joinedYear: 2024,
      seasonLine: '13 apps · 6 clean sheets',
      rsvpStatus: RsvpStatus.yes,
      amountOwed: 0,
      card: PlayerCard(
        apps: 13,
        goals: 0,
        assists: 1,
        stats: [
          PlayerStat(label: 'Diving', value: 81),
          PlayerStat(label: 'Handling', value: 79),
          PlayerStat(label: 'Kicking', value: 74),
          PlayerStat(label: 'Reflexes', value: 83),
          PlayerStat(label: 'Speed', value: 58),
          PlayerStat(label: 'Positioning', value: 80),
        ],
      ),
    ),
  ];

  @override
  Future<Either<Failure, TeamSnapshot>> getTeamSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Right(
      TeamSnapshot(
        team: TeamInfo(
          name: 'Golden Goal FC',
          meta: '18 players · Bangkok 5-a-side',
          initials: 'GG',
          alertCount: 3,
        ),
        match: UpcomingMatch(
          opponent: 'Sundown United',
          kickoffLabel: 'SUN · 5:30 PM',
          countdownLabel: 'in 3 days',
          venueLine: 'Rajamangala 5-a-side · Court 2',
          confirmedOf: '11/15',
          feePerPlayer: '฿150',
          kit: 'Gold',
          temperatureC: 29,
          rainChancePercent: 20,
          rsvpClosesLabel: 'Closes Fri 8:00 pm',
          hubLine1: 'Kickoff Sun 5:30 PM at Rajamangala 5-a-side, Court 2.',
          hubLine2: 'RSVP closes Friday 8:00 PM — 11 of 15 confirmed so far.',
        ),
        needsYou: [
          NeedsYouItem(
            kind: NeedsYouKind.vote,
            title: 'MOTM voting is open',
            meta: '3 nominees · closes tonight',
          ),
          NeedsYouItem(
            kind: NeedsYouKind.wallet,
            title: 'You owe ฿150',
            meta: "For last Sunday's match",
          ),
          NeedsYouItem(
            kind: NeedsYouKind.availability,
            title: 'Availability · 14 of 18 fit',
            meta: 'Kaká limited (knock) · Pato away',
          ),
        ],
        lastResult: MatchResult(
          homeTeam: 'Golden Goal',
          awayTeam: 'Riverside',
          homeScore: 4,
          awayScore: 2,
          summary:
              "Messi 12', 78' · Ronaldinho 34' · Kaká 67' · MOTM voting closes tonight",
        ),
        roster: _roster,
        teamBalance: '฿4,250',
        monthIn: '+฿8,500',
        monthOut: '−฿6,200',
        monthNet: '+฿2,300',
        ledger: [
          LedgerEntry(
            label: 'Sunday match fees',
            meta: '5 players paid',
            amount: '+฿1,650',
            isCredit: true,
          ),
          LedgerEntry(
            label: 'Pitch rental · Rajamangala',
            meta: 'Aug 24',
            amount: '−฿2,400',
            isCredit: false,
          ),
          LedgerEntry(
            label: 'Referee fee',
            meta: 'Aug 24',
            amount: '−฿800',
            isCredit: false,
          ),
          LedgerEntry(
            label: 'Kit deposit refund',
            meta: 'Aug 20',
            amount: '+฿500',
            isCredit: true,
          ),
          LedgerEntry(
            label: 'Water & snacks',
            meta: 'Aug 18',
            amount: '−฿350',
            isCredit: false,
          ),
        ],
      ),
    );
  }
}
