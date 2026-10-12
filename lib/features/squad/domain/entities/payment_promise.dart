import 'package:equatable/equatable.dart';

/// "I'll pay you on the 25th": [fromId] promised [toId] to settle up on
/// [promisedOn] — for a trip ([tripId]) or the squad. Until then reminders
/// about it wait (see supabase/sql/044_squad_payments.sql).
class PaymentPromise extends Equatable {
  const PaymentPromise({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.promisedOn,
    this.tripId,
  });

  final String id;
  final String fromId;
  final String toId;

  /// A calendar day (no time).
  final DateTime promisedOn;
  final String? tripId;

  static DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);

  /// Still to come: today counts, as the day it's due.
  bool isActive({DateTime? now}) => !_day(promisedOn).isBefore(_day(now ?? DateTime.now()));

  /// The day hasn't come yet — reminders wait.
  bool isAhead({DateTime? now}) => _day(promisedOn).isAfter(_day(now ?? DateTime.now()));

  bool isDueToday({DateTime? now}) => _day(promisedOn) == _day(now ?? DateTime.now());

  @override
  List<Object?> get props => [id, fromId, toId, promisedOn, tripId];
}
