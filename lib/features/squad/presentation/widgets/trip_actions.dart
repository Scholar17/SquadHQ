import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/trip.dart';
import '../squad_formatting.dart';
import 'expense_sheet.dart';
import 'squad_widgets.dart';
import 'trip_sheet.dart';

/// Open trips you can add to: ones you're on, or any for an admin.
List<Trip> openTripsFor(SquadLedger ledger, String me) {
  final isAdmin = ledger.member(me)?.isAdmin ?? false;
  return [
    for (final trip in ledger.trips)
      if (!trip.isClosed && (trip.includes(me) || isAdmin)) trip,
  ];
}

/// Whether to offer "Add trip expense": a trip's open for you, or you're
/// an admin who can start one.
bool canAddTripExpense(SquadLedger ledger, String me) =>
    (ledger.member(me)?.isAdmin ?? false) || openTripsFor(ledger, me).isNotEmpty;

/// "Add trip expense" from Home or the Expenses tab. One open trip: straight to the sheet.
/// Several: pick which (admins can also start a new one). None: an admin
/// starts one first.
Future<void> addTripExpense(
  BuildContext context, {
  required String teamId,
  required SquadLedger ledger,
  required String me,
}) async {
  final isAdmin = ledger.member(me)?.isAdmin ?? false;
  final trips = openTripsFor(ledger, me);
  // Your payment QR first — before starting a trip too, not just before
  // its expense sheet.
  if (!await ensurePaymentQr(context, me: me) || !context.mounted) return;
  if (trips.isEmpty) {
    if (isAdmin) await showTripSheet(context, teamId: teamId, me: me);
    return;
  }
  // Null: closed the picker. A trip id: add to it. '' : start a new trip.
  final picked = trips.length == 1
      ? trips.single.id
      : await showModalBottomSheet<String>(
          context: context,
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.sheet,
          ),
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text('Which trip?', style: AppTextStyles.title(size: 18)),
                ),
                for (final trip in trips)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(Icons.luggage_outlined, color: oweColor),
                    title: Text(
                      trip.name,
                      style: AppTextStyles.body(size: 15, weight: FontWeight.w600),
                    ),
                    subtitle: Text(formatTripDates(trip.startsOn, trip.endsOn)),
                    onTap: () => Navigator.of(context).pop(trip.id),
                  ),
                if (isAdmin)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(Icons.add_rounded, color: oweColor),
                    title: Text(
                      'New trip',
                      style: AppTextStyles.body(size: 15, weight: FontWeight.w700, color: oweColor),
                    ),
                    onTap: () => Navigator.of(context).pop(''),
                  ),
              ],
            ),
          ),
        );
  if (picked == null || !context.mounted) return;
  if (picked.isEmpty) {
    await showTripSheet(context, teamId: teamId, me: me);
  } else {
    await showExpenseSheet(context, teamId: teamId, me: me, tripId: picked);
  }
}
