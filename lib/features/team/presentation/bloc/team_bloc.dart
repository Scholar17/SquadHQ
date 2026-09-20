import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/team_snapshot.dart';
import '../../domain/repositories/team_repository.dart';
import 'team_event.dart';
import 'team_state.dart';

class TeamBloc extends Bloc<TeamEvent, TeamState> {
  TeamBloc(this._repository) : super(const TeamLoading()) {
    on<TeamStarted>(_onStarted);
    on<TeamRoleToggled>(_onRoleToggled);
    on<TeamMyRsvpChanged>(_onMyRsvpChanged);
    on<TeamMatchDetailsUpdated>(_onMatchDetailsUpdated);
    on<TeamBillSplit>(_onBillSplit);
  }

  final TeamRepository _repository;

  Future<void> _onStarted(TeamStarted event, Emitter<TeamState> emit) async {
    emit(const TeamLoading());
    final result = await _repository.getTeamSnapshot();
    result.fold(
      (failure) => emit(TeamError(failure.message)),
      (snapshot) => emit(
        TeamLoaded(
          snapshot: snapshot,
          role: SquadRole.manager,
          myRsvp: RsvpStatus.pending,
        ),
      ),
    );
  }

  void _onRoleToggled(TeamRoleToggled event, Emitter<TeamState> emit) {
    final current = state;
    if (current is! TeamLoaded) return;
    emit(
      current.copyWith(
        role: current.role == SquadRole.manager
            ? SquadRole.player
            : SquadRole.manager,
      ),
    );
  }

  void _onMyRsvpChanged(TeamMyRsvpChanged event, Emitter<TeamState> emit) {
    final current = state;
    if (current is! TeamLoaded) return;
    emit(current.copyWith(myRsvp: event.status));
  }

  void _onMatchDetailsUpdated(
    TeamMatchDetailsUpdated event,
    Emitter<TeamState> emit,
  ) {
    final current = state;
    if (current is! TeamLoaded) return;
    final match = current.snapshot.match.copyWith(
      opponent: event.opponent,
      kickoffLabel: event.kickoffLabel,
      venueLine: event.venueLine,
      feePerPlayer: event.feePerPlayer,
      kit: event.kit,
      hubLine1: 'Kickoff ${event.kickoffLabel} at ${event.venueLine}.',
      hubLine2:
          'RSVP ${current.snapshot.match.rsvpClosesLabel.toLowerCase()} — ${current.snapshot.match.confirmedOf} confirmed so far.',
    );
    emit(
      TeamLoaded(
        snapshot: current.snapshot.copyWith(match: match),
        role: current.role,
        myRsvp: current.myRsvp,
      ),
    );
  }

  void _onBillSplit(TeamBillSplit event, Emitter<TeamState> emit) {
    final current = state;
    if (current is! TeamLoaded) return;
    final total = event.rentFee + event.waterFee + event.additionalCost;
    if (total <= 0 || event.shares.isEmpty) return;

    final roster = [
      for (final member in current.snapshot.roster)
        if (event.shares[member.id] case final charge?)
          member.copyWith(amountOwed: member.amountOwed + charge)
        else
          member,
    ];

    final breakdown = [
      'Rent ${_formatBaht(event.rentFee)}',
      'Water ${_formatBaht(event.waterFee)}',
      if (event.additionalCost > 0)
        '${event.additionalLabel} ${_formatBaht(event.additionalCost)}',
    ].join(' · ');
    final chargedCount = event.shares.values.where((amount) => amount > 0).length;

    final ledger = [
      LedgerEntry(
        label: 'Match bill · $breakdown',
        meta: 'Split across $chargedCount player${chargedCount == 1 ? '' : 's'}',
        amount: _formatBaht(-total, signed: true),
        isCredit: false,
      ),
      ...current.snapshot.ledger,
    ];

    final newBalance = _parseBaht(current.snapshot.teamBalance) - total;
    final newMonthOut = _parseBaht(current.snapshot.monthOut) - total;
    final newMonthNet = _parseBaht(current.snapshot.monthIn) + newMonthOut;

    emit(
      TeamLoaded(
        snapshot: current.snapshot.copyWith(
          roster: roster,
          ledger: ledger,
          teamBalance: _formatBaht(newBalance),
          monthOut: _formatBaht(newMonthOut, signed: true),
          monthNet: _formatBaht(newMonthNet, signed: true),
        ),
        role: current.role,
        myRsvp: current.myRsvp,
      ),
    );
  }
}

/// Reads formatted amounts like '฿4,250', '+฿8,500' or '−฿6,200'.
double _parseBaht(String value) {
  final isNegative = value.contains('-') || value.contains('−');
  final digits = value.replaceAll(RegExp(r'[^0-9.]'), '');
  final magnitude = double.tryParse(digits) ?? 0;
  return isNegative ? -magnitude : magnitude;
}

/// Mirrors the mock data's baht formatting: thousands separators, and an
/// explicit +/− sign when [signed] is true.
String _formatBaht(double value, {bool signed = false}) {
  final rounded = value.abs().round();
  final withCommas = rounded.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (match) => ',',
      );
  if (!signed) return '฿$withCommas';
  return '${value < 0 ? '−' : '+'}฿$withCommas';
}
