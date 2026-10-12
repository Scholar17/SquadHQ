import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/squad_ledger.dart';
import '../../domain/entities/trip.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// A trip at a glance — name, dates, people, total — and where [me]
/// stands for it alone: Open, You pay ฿X, You get ฿X or Settled. Taps
/// through to the trip. [ledger] is the squad's (with its trips).
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.ledger, required this.me});

  final Trip trip;
  final SquadLedger ledger;
  final String me;

  @override
  Widget build(BuildContext context) {
    final tripLedger = ledger.forTrip(trip.id);
    final total = tripLedger.expenses.fold(0, (sum, e) => sum + e.amountCents);
    final balance = tripLedger.balanceOf(me);
    final (status, color) = switch (trip) {
      _ when !trip.isClosed => ('Open', oweColor),
      _ when !trip.includes(me) || balance == 0 => ('Settled', owedColor),
      _ when balance < 0 => ('You pay ${formatMoney(-balance, ledger.currency)}', oweColor),
      _ => ('You get ${formatMoney(balance, ledger.currency)}', owedColor),
    };
    return SquadCard(
      onTap: () => context.push(AppRoutes.trip(trip.id)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(Icons.luggage_outlined, size: 20, color: oweColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(size: 15, height: 1.3),
                ),
                Text(
                  '${formatTripDates(trip.startsOn, trip.endsOn)} · '
                  '${trip.memberIds.length} people · '
                  '${formatMoney(total, ledger.currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 12, color: squadMuted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: AppTextStyles.body(size: 12.5, weight: FontWeight.w800, color: color),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: squadMuted),
        ],
      ),
    );
  }
}
