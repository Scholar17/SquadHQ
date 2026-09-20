import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/team_snapshot.dart';
import '../bloc/team_bloc.dart';
import '../bloc/team_event.dart';

/// Opened from the matchday hub's "Edit details" button — manager-only.
Future<void> showEditMatchDetailsSheet(
  BuildContext context, {
  required UpcomingMatch match,
}) {
  final teamBloc = context.read<TeamBloc>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => BlocProvider.value(
      value: teamBloc,
      child: _EditMatchDetailsSheet(match: match),
    ),
  );
}

class _EditMatchDetailsSheet extends StatefulWidget {
  const _EditMatchDetailsSheet({required this.match});

  final UpcomingMatch match;

  @override
  State<_EditMatchDetailsSheet> createState() => _EditMatchDetailsSheetState();
}

class _EditMatchDetailsSheetState extends State<_EditMatchDetailsSheet> {
  late final _opponentController = TextEditingController(text: widget.match.opponent);
  late final _kickoffController = TextEditingController(text: widget.match.kickoffLabel);
  late final _venueController = TextEditingController(text: widget.match.venueLine);
  late final _feeController = TextEditingController(text: widget.match.feePerPlayer);
  late final _kitController = TextEditingController(text: widget.match.kit);

  @override
  void dispose() {
    _opponentController.dispose();
    _kickoffController.dispose();
    _venueController.dispose();
    _feeController.dispose();
    _kitController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _opponentController.text.trim().isNotEmpty &&
      _kickoffController.text.trim().isNotEmpty &&
      _venueController.text.trim().isNotEmpty;

  void _save() {
    if (!_isValid) return;
    context.read<TeamBloc>().add(
          TeamMatchDetailsUpdated(
            opponent: _opponentController.text.trim(),
            kickoffLabel: _kickoffController.text.trim(),
            venueLine: _venueController.text.trim(),
            feePerPlayer: _feeController.text.trim(),
            kit: _kitController.text.trim(),
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit match details', style: AppTextStyles.heading(size: 18)),
          const SizedBox(height: 16),
          _Field(controller: _opponentController, label: 'Opponent'),
          const SizedBox(height: 10),
          _Field(controller: _kickoffController, label: 'Kickoff'),
          const SizedBox(height: 10),
          _Field(controller: _venueController, label: 'Venue'),
          const SizedBox(height: 10),
          _Field(controller: _feeController, label: 'Fee per player'),
          const SizedBox(height: 10),
          _Field(controller: _kitController, label: 'Kit'),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.bg,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text('Save changes', style: AppTextStyles.heading(size: 14, color: AppColors.bg)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          filled: true,
          fillColor: AppColors.neutral100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
          ),
        ),
      ),
    );
  }
}
