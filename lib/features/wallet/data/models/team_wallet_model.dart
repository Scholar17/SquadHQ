import '../../../match/data/models/match_model.dart';
import '../../../match/data/models/matchday_player_model.dart';
import '../../../match/domain/entities/matchday_player.dart';
import '../../domain/entities/team_wallet.dart';

SplitMode splitModeFromDb(String value) => switch (value) {
      'team' => SplitMode.team,
      'custom' => SplitMode.custom,
      _ => SplitMode.rsvpIn,
    };

String splitModeToDb(SplitMode mode) => switch (mode) {
      SplitMode.rsvpIn => 'in',
      SplitMode.team => 'team',
      SplitMode.custom => 'custom',
    };

/// Builds a [TeamWallet] from the three queries in
/// WalletRemoteDataSourceImpl.getTeamWallet.
abstract final class TeamWalletModel {
  /// [memberRows]: `team_members` with `profiles(name)` embedded.
  /// [matchRows]: `matches` with the payer's profile, `match_bill_members`
  /// and `match_payments` embedded. [rsvpRows]: `match_rsvps` for them.
  static TeamWallet fromRows({
    required List<Map<String, dynamic>> memberRows,
    required List<Map<String, dynamic>> matchRows,
    required List<Map<String, dynamic>> rsvpRows,
  }) {
    final answersByMatch = <String, Map<String, RsvpAnswer>>{};
    for (final row in rsvpRows) {
      final answer = rsvpAnswerFromDb(row['status'] as String?);
      if (answer == null) continue;
      (answersByMatch[row['match_id'] as String] ??= {})[row['profile_id'] as String] = answer;
    }
    return TeamWallet(
      members: [
        for (final row in memberRows)
          WalletMember(
            profileId: row['profile_id'] as String,
            name: ((row['profiles'] as Map<String, dynamic>?)?['name'] as String?) ??
                'Unknown player',
          ),
      ],
      matches: [
        for (final row in matchRows)
          WalletMatch(
            match: MatchModel.fromRow(row),
            bill: _billFromRow(row),
            answers: answersByMatch[row['id'] as String] ?? const {},
          ),
      ],
    );
  }

  static MatchBill? _billFromRow(Map<String, dynamic> row) {
    final totalCost = (row['total_cost'] as num?)?.toDouble();
    if (totalCost == null) return null;
    final payer = row['payer'] as Map<String, dynamic>?;
    return MatchBill(
      totalCost: totalCost,
      payerId: row['paid_by'] as String?,
      payerName: (payer?['name'] as String?) ?? 'A former teammate',
      payerQrPath: payer?['wallet_qr_path'] as String?,
      splitMode: splitModeFromDb(row['split_mode'] as String),
      customMemberIds: {
        for (final member in (row['match_bill_members'] as List<dynamic>? ?? const []))
          (member as Map<String, dynamic>)['profile_id'] as String,
      },
      remindedAt: _latestReminders(row['bill_reminders'] as List<dynamic>? ?? const []),
      payments: {
        for (final payment in (row['match_payments'] as List<dynamic>? ?? const []))
          (payment as Map<String, dynamic>)['profile_id'] as String: BillPayment(
            profileId: payment['profile_id'] as String,
            slipPath: payment['slip_path'] as String,
            paidAt: DateTime.parse(payment['paid_at'] as String),
          ),
      },
    );
  }

  /// Each player's most recent reminder time.
  static Map<String, DateTime> _latestReminders(List<dynamic> rows) {
    final latest = <String, DateTime>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final profileId = row['profile_id'] as String;
      final at = DateTime.parse(row['reminded_at'] as String);
      final current = latest[profileId];
      if (current == null || at.isAfter(current)) latest[profileId] = at;
    }
    return latest;
  }
}
