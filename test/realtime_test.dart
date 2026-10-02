import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/core/realtime/team_changes.dart';
import 'package:squad_hq/features/match/domain/entities/matchday_player.dart';
import 'package:squad_hq/features/match/domain/usecases/create_match.dart';
import 'package:squad_hq/features/match/domain/usecases/delete_match.dart';
import 'package:squad_hq/features/match/domain/usecases/get_matchday_roster.dart';
import 'package:squad_hq/features/match/domain/usecases/get_upcoming_matches.dart';
import 'package:squad_hq/features/match/domain/usecases/nudge_match_rsvp.dart';
import 'package:squad_hq/features/match/domain/usecases/set_match_rsvp.dart';
import 'package:squad_hq/features/match/domain/usecases/update_match.dart';
import 'package:squad_hq/features/match/presentation/bloc/match_bloc.dart';
import 'package:squad_hq/features/match/presentation/bloc/match_event.dart';
import 'package:squad_hq/features/match/presentation/bloc/match_state.dart';
import 'package:squad_hq/features/match/presentation/bloc/matchday_bloc.dart';
import 'package:squad_hq/features/match/presentation/bloc/matchday_event.dart';
import 'package:squad_hq/features/match/presentation/bloc/matchday_state.dart';
import 'package:squad_hq/features/wallet/domain/entities/team_wallet.dart';
import 'package:squad_hq/features/wallet/domain/usecases/get_team_wallet.dart';
import 'package:squad_hq/features/wallet/domain/usecases/remind_unpaid.dart';
import 'package:squad_hq/features/wallet/domain/usecases/set_match_bill.dart';
import 'package:squad_hq/features/wallet/domain/usecases/submit_bill_payment.dart';
import 'package:squad_hq/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:squad_hq/features/wallet/presentation/bloc/wallet_event.dart';
import 'package:squad_hq/features/wallet/presentation/bloc/wallet_state.dart';

import 'fake_match_repository.dart';
import 'fake_team_changes.dart';
import 'fake_wallet_repository.dart';

void main() {
  late FakeMatchRepository matches;
  late FakeWalletRepository wallet;
  late FakeTeamChanges changes;

  setUp(() {
    matches = FakeMatchRepository(teamId: 'team-1', userId: 'test-1');
    wallet = FakeWalletRepository(matches);
    changes = FakeTeamChanges();
  });

  WalletBloc walletBloc() => WalletBloc(
        getTeamWallet: GetTeamWallet(wallet),
        setMatchBill: SetMatchBill(wallet),
        submitBillPayment: SubmitBillPayment(wallet),
        remindUnpaid: RemindUnpaid(wallet),
        teamChanges: changes,
      );

  MatchBill? billFor(WalletState state, String matchId) => switch (state) {
        WalletLoaded(:final wallet) =>
          wallet.matches.firstWhere((m) => m.match.id == matchId).bill,
        _ => null,
      };

  test("Wallet: a teammate's bill change shows without a refresh", () async {
    final bloc = walletBloc()..add(const WalletTeamSelected('team-1'));
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((s) => s is WalletLoaded);
    expect(billFor(bloc.state, 'match-1'), isNull);

    wallet.bills['match-1'] = const MatchBill(
      totalCost: 30000,
      payerId: 'admin',
      payerName: 'Aung Ko',
      splitMode: SplitMode.rsvpIn,
    );
    // A burst, as one bill save touches several rows: one reload.
    changes
      ..push('team-1', TeamTable.matches)
      ..push('team-1', TeamTable.matchBillMembers)
      ..push('team-1', TeamTable.matchPayments);

    final reloaded = await bloc.stream.first.timeout(const Duration(seconds: 2));
    expect(billFor(reloaded, 'match-1')?.totalCost, 30000);
  });

  test("Wallet ignores tables it doesn't show, and other teams", () async {
    final bloc = walletBloc()..add(const WalletTeamSelected('team-1'));
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((s) => s is WalletLoaded);

    var reloads = 0;
    final sub = bloc.stream.listen((_) => reloads++);
    addTearDown(sub.cancel);
    wallet.bills['match-1'] = const MatchBill(
      totalCost: 1,
      payerId: 'admin',
      payerName: 'Aung Ko',
      splitMode: SplitMode.rsvpIn,
    );
    changes
      ..push('team-1', TeamTable.motmVotes)
      ..push('team-2', TeamTable.matchPayments);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(reloads, 0);
  });

  test("Home/Match: a match a teammate creates appears without a refresh", () async {
    final bloc = MatchBloc(
      getUpcomingMatches: GetUpcomingMatches(matches),
      createMatch: CreateMatch(matches),
      updateMatch: UpdateMatch(matches),
      deleteMatch: DeleteMatch(matches),
      nudgeMatchRsvp: NudgeMatchRsvp(matches),
      teamChanges: changes,
    )..add(const MatchTeamSelected('team-1'));
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((s) => s is MatchLoaded);
    expect((bloc.state as MatchLoaded).matches, hasLength(1));

    await matches.createMatch(
      teamId: 'team-1',
      opponent: 'Riverside FC',
      kickoffAt: DateTime(2026, 10, 10, 19),
      durationMinutes: 90,
    );
    changes.push('team-1', TeamTable.matches);

    final reloaded = await bloc.stream.first.timeout(const Duration(seconds: 2));
    expect((reloaded as MatchLoaded).matches, hasLength(2));
  });

  test("Match tab: a teammate's RSVP shows without a refresh", () async {
    final match = (await matches.getUpcomingMatches('team-1')).getOrElse(() => []).first;
    final bloc = MatchdayBloc(
      match: match,
      getMatchdayRoster: GetMatchdayRoster(matches),
      setMatchRsvp: SetMatchRsvp(matches),
      teamChanges: changes,
    )..add(const MatchdayStarted());
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((s) => s is MatchdayLoaded);
    final before = (bloc.state as MatchdayLoaded).countOf(RsvpAnswer.yes);

    matches.addVoters(['Zaw Win'], RsvpAnswer.yes);
    changes.push('team-1', TeamTable.matchRsvps);

    final reloaded = await bloc.stream.first.timeout(const Duration(seconds: 2));
    expect((reloaded as MatchdayLoaded).countOf(RsvpAnswer.yes), before + 1);
  });

  test('Watches only the selected team, and stops on close', () async {
    final bloc = walletBloc()..add(const WalletTeamSelected('team-1'));
    await bloc.stream.firstWhere((s) => s is WalletLoaded);
    expect(changes.watchers['team-1'], 1);

    bloc.add(const WalletTeamSelected('team-2'));
    await bloc.stream.firstWhere((s) => s is WalletLoaded);
    expect(changes.watchers, {'team-1': 0, 'team-2': 1});

    bloc.add(const WalletTeamSelected(null));
    await bloc.stream.firstWhere((s) => s is WalletLoaded);
    expect(changes.watchers['team-2'], 0);

    bloc.add(const WalletTeamSelected('team-1'));
    await bloc.stream.firstWhere((s) => s is WalletLoaded);
    await bloc.close();
    expect(changes.watchers['team-1'], 0);
  });
}
