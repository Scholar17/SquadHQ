import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/usecases/squad_usecases.dart';
import '../bloc/squad_ledger_bloc.dart';
import 'squad_widgets.dart';

/// "Remind to pay": nudges each person in [amounts] about what they owe
/// you — for [tripId], or the squad — once a day each (remind_to_pay,
/// supabase/sql/035_remind_to_pay.sql). Shows "Reminded" once everyone in
/// it has been reminded today.
class RemindButton extends StatelessWidget {
  const RemindButton({
    super.key,
    required this.teamId,
    required this.amounts,
    required this.remindedToday,
    this.tripId,
    this.label = 'Remind',
    this.onDark = false,
  });

  final String teamId;

  /// Who to remind, and what each owes you.
  final Map<String, int> amounts;

  /// Every one of [amounts] was already reminded today.
  final bool remindedToday;
  final String? tripId;
  final String label;

  /// Styled for the dark hero card.
  final bool onDark;

  @override
  Widget build(BuildContext context) => ReminderButton(
    label: label,
    done: remindedToday,
    onDark: onDark,
    send: () async =>
        (await sl<RemindToPay>()((teamId: teamId, amounts: amounts, tripId: tripId)))
            .map((count) => count == 1 ? 'Reminder sent.' : 'Reminders sent to $count people.'),
  );
}

/// "Remind to confirm": the payer nudges whoever they paid while the
/// payment is pending — once a day (nudge_settlement, 027).
class ConfirmReminderButton extends StatelessWidget {
  const ConfirmReminderButton({
    super.key,
    required this.settlementId,
    required this.receiverName,
    required this.remindedToday,
    this.onDark = false,
  });

  final String settlementId;
  final String receiverName;
  final bool remindedToday;

  /// Styled for the dark hero card.
  final bool onDark;

  @override
  Widget build(BuildContext context) => ReminderButton(
    label: 'Remind to confirm',
    done: remindedToday,
    onDark: onDark,
    send: () async =>
        (await sl<NudgeSettlement>()(settlementId))
            .map((_) => 'Reminded $receiverName to confirm.'),
  );
}

/// A once-a-day reminder button: [send] it, show its message (or the
/// failure), refresh the squad — and show "Reminded" while [done].
class ReminderButton extends StatefulWidget {
  const ReminderButton({
    super.key,
    required this.label,
    required this.done,
    required this.send,
    this.onDark = false,
  });

  final String label;
  final bool done;

  /// Returns the success message.
  final Future<Either<Failure, String>> Function() send;
  final bool onDark;

  @override
  State<ReminderButton> createState() => _ReminderButtonState();
}

class _ReminderButtonState extends State<ReminderButton> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    final result = await widget.send();
    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.fold((failure) => messenger.showSnackBar(SnackBar(content: Text(failure.message))), (
      message,
    ) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
      context.read<SquadLedgerBloc>().add(const SquadRefreshRequested());
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.done;
    final fg = widget.onDark ? AppColors.onDark : oweColor;
    final disabledFg = widget.onDark ? AppColors.onDark.withValues(alpha: 0.55) : squadMuted;
    return Semantics(
      button: true,
      enabled: !done && !_sending,
      child: TextButton.icon(
        onPressed: done || _sending ? null : _send,
        icon: _sending
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Icon(done ? Icons.check_rounded : Icons.notifications_active_outlined, size: 16),
        label: Text(
          done ? 'Reminded' : widget.label,
          style: AppTextStyles.body(size: 12.5, weight: FontWeight.w800, height: 1.2),
        ),
        style: TextButton.styleFrom(
          foregroundColor: fg,
          disabledForegroundColor: disabledFg,
          backgroundColor: widget.onDark
              ? Colors.transparent
              : (done ? AppColors.neutral200 : AppColors.accent100),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: StadiumBorder(
            side: widget.onDark
                ? BorderSide(color: AppColors.onDark.withValues(alpha: 0.35))
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
