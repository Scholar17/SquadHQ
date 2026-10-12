import 'package:equatable/equatable.dart';

/// Values match settlements.method.
enum SettlementMethod {
  qr('QR'),
  bank('Bank'),
  cash('Cash');

  const SettlementMethod(this.label);

  final String label;
}

/// Values match settlements.status. Only [confirmed] counts toward
/// balances.
enum SettlementStatus { pending, confirmed, rejected }

/// One member paying another back.
class Settlement extends Equatable {
  const Settlement({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amountCents,
    required this.method,
    required this.status,
    required this.createdAt,
    this.slipPath,
    this.rejectReason,
    this.respondedAt,
    this.nudgedAt,
    this.tripId,
    this.recordedBy,
    this.sentCents,
  });

  final String id;
  final String fromId;
  final String toId;
  final int amountCents;
  final SettlementMethod method;
  final SettlementStatus status;
  final DateTime createdAt;
  final String? slipPath;
  final String? rejectReason;
  final DateTime? respondedAt;

  /// When the payer last sent "Remind to confirm".
  final DateTime? nudgedAt;

  /// The trip it pays back; null for the squad's own.
  final String? tripId;

  /// Recorded by whoever was owed — cash they got in hand — rather than
  /// sent by the payer (044). Confirmed from the start.
  final String? recordedBy;

  /// What the payer sent, when the receiver confirmed getting only part of
  /// it ([amountCents]); the rest still counts as owed (044).
  final int? sentCents;

  /// Confirmed for less than was sent.
  bool get isPartlyReceived => sentCents != null && sentCents! > amountCents;

  /// The payer already sent "Remind to confirm" today (phone's day; the
  /// server checks by the squad's time zone).
  bool nudgedToday({DateTime? now}) {
    final at = nudgedAt?.toLocal();
    final today = (now ?? DateTime.now()).toLocal();
    return at != null && at.year == today.year && at.month == today.month && at.day == today.day;
  }

  bool get isPending => status == SettlementStatus.pending;
  bool get isConfirmed => status == SettlementStatus.confirmed;
  bool get isRejected => status == SettlementStatus.rejected;

  @override
  List<Object?> get props => [
    id,
    fromId,
    toId,
    amountCents,
    method,
    status,
    createdAt,
    slipPath,
    rejectReason,
    respondedAt,
    nudgedAt,
    tripId,
    recordedBy,
    sentCents,
  ];
}
