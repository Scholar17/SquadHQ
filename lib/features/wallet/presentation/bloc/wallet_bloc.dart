import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/team_changes.dart';
import '../../domain/entities/team_wallet.dart';
import '../../domain/usecases/get_team_wallet.dart';
import '../../domain/usecases/remind_unpaid.dart';
import '../../domain/usecases/set_match_bill.dart';
import '../../domain/usecases/submit_bill_payment.dart';
import 'wallet_event.dart';
import 'wallet_state.dart';

/// Singleton, provided at the app root (see app.dart) like MatchBloc — the
/// Wallet tab, the Match tab's bill card and the bill/pay sheets all share
/// it, so a bill edited in one place shows everywhere.
class WalletBloc extends Bloc<WalletEvent, WalletState> {
  WalletBloc({
    required GetTeamWallet getTeamWallet,
    required SetMatchBill setMatchBill,
    required SubmitBillPayment submitBillPayment,
    required RemindUnpaid remindUnpaid,
    required TeamChanges teamChanges,
  })  : _remindUnpaid = remindUnpaid,
        _getTeamWallet = getTeamWallet,
        _setMatchBill = setMatchBill,
        _submitBillPayment = submitBillPayment,
        super(const WalletLoading()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {
        TeamTable.teamMembers,
        TeamTable.matches,
        TeamTable.matchRsvps,
        TeamTable.matchBillMembers,
        TeamTable.matchPayments,
        TeamTable.billReminders,
      },
      onChange: () {
        if (!isClosed) add(const WalletRefreshRequested());
      },
    );
    on<WalletTeamSelected>(_onTeamSelected);
    on<WalletRefreshRequested>(_onRefreshRequested);
    on<WalletBillSaveRequested>(_onBillSaveRequested);
    on<WalletPaymentSubmitted>(_onPaymentSubmitted);
    on<WalletRemindUnpaidRequested>(_onRemindUnpaidRequested);
  }

  final GetTeamWallet _getTeamWallet;
  final SetMatchBill _setMatchBill;
  final SubmitBillPayment _submitBillPayment;
  final RemindUnpaid _remindUnpaid;

  /// Reloads when a teammate pays, edits a bill, RSVPs or is reminded.
  late final TeamChangeWatcher _serverChanges;

  String? _teamId;

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
  }

  Future<void> _reload(Emitter<WalletState> emit) async {
    final teamId = _teamId;
    if (teamId == null) {
      emit(const WalletLoaded(TeamWallet.empty));
      return;
    }
    final result = await _getTeamWallet(teamId);
    result.fold(
      (failure) => emit(WalletFailure(failure.message, const WalletLoaded(TeamWallet.empty))),
      (wallet) => emit(WalletLoaded(wallet)),
    );
  }

  Future<void> _onTeamSelected(WalletTeamSelected event, Emitter<WalletState> emit) async {
    _serverChanges.watch(event.teamId);
    _teamId = event.teamId;
    emit(const WalletLoading());
    await _reload(emit);
  }

  Future<void> _onRefreshRequested(
    WalletRefreshRequested event,
    Emitter<WalletState> emit,
  ) async {
    try {
      await _reload(emit);
    } finally {
      event.done?.complete();
    }
  }

  Future<void> _onBillSaveRequested(
    WalletBillSaveRequested event,
    Emitter<WalletState> emit,
  ) async {
    final fallback = state.settled;
    emit(WalletSubmitting(fallback));
    final result = await _setMatchBill(
      SetMatchBillParams(
        matchId: event.matchId,
        totalCost: event.totalCost,
        splitMode: event.splitMode,
        memberIds: event.memberIds,
      ),
    );
    await result.fold(
      (failure) async => emit(WalletFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onPaymentSubmitted(
    WalletPaymentSubmitted event,
    Emitter<WalletState> emit,
  ) async {
    final fallback = state.settled;
    emit(WalletSubmitting(fallback));
    final result = await _submitBillPayment(
      SubmitBillPaymentParams(
        matchId: event.matchId,
        slipBytes: event.slipBytes,
        fileExtension: event.fileExtension,
      ),
    );
    await result.fold(
      (failure) async => emit(WalletFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }

  Future<void> _onRemindUnpaidRequested(
    WalletRemindUnpaidRequested event,
    Emitter<WalletState> emit,
  ) async {
    final fallback = state.settled;
    emit(WalletSubmitting(fallback));
    final result = await _remindUnpaid(
      RemindUnpaidParams(matchId: event.matchId, profileIds: event.profileIds),
    );
    await result.fold(
      (failure) async => emit(WalletFailure(failure.message, fallback)),
      (_) => _reload(emit),
    );
  }
}
