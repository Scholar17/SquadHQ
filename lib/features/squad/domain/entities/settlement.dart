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
  ];
}
