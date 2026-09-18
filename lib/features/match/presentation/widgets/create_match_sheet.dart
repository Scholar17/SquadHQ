import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../bloc/match_bloc.dart';
import '../bloc/match_event.dart';
import '../bloc/match_state.dart';

/// Opened from Home's "+ New match" button — only ever shown to a team's
/// admin/super admin, but `create_match` (supabase/sql/006_create_matches.sql)
/// enforces that server-side too.
Future<void> showCreateMatchSheet(BuildContext context, {required String teamId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CreateMatchSheet(teamId: teamId),
  );
}

class _CreateMatchSheet extends StatefulWidget {
  const _CreateMatchSheet({required this.teamId});

  final String teamId;

  @override
  State<_CreateMatchSheet> createState() => _CreateMatchSheetState();
}

class _CreateMatchSheetState extends State<_CreateMatchSheet> {
  final _opponentController = TextEditingController();
  final _venueController = TextEditingController();
  final _feeController = TextEditingController();
  DateTime? _kickoffAt;

  @override
  void dispose() {
    _opponentController.dispose();
    _venueController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _pickKickoff() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;
    setState(() {
      _kickoffAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  bool get _isValid => _opponentController.text.trim().isNotEmpty && _kickoffAt != null;

  void _submit() {
    if (!_isValid) return;
    context.read<MatchBloc>().add(
          MatchCreateRequested(
            teamId: widget.teamId,
            opponent: _opponentController.text.trim(),
            kickoffAt: _kickoffAt!,
            venue: _venueController.text.trim().isEmpty ? null : _venueController.text.trim(),
            feePerPlayer: double.tryParse(_feeController.text.trim()),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MatchBloc, MatchState>(
      listenWhen: (previous, current) =>
          current is MatchFailure || (previous is MatchSubmitting && current is MatchLoaded),
      listener: (context, state) {
        if (state case MatchFailure(:final message)) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          return;
        }
        if (state is MatchLoaded) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
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
            Text('New match', style: AppTextStyles.heading(size: 18)),
            const SizedBox(height: 16),
            _Field(controller: _opponentController, hintText: 'Opponent'),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _pickKickoff,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.text.withValues(alpha: 0.16)),
                ),
                child: Text(
                  _kickoffAt == null
                      ? 'Date & time'
                      : '${_kickoffAt!.day}/${_kickoffAt!.month}/${_kickoffAt!.year} '
                          '${_kickoffAt!.hour.toString().padLeft(2, '0')}:'
                          '${_kickoffAt!.minute.toString().padLeft(2, '0')}',
                  style: AppTextStyles.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: _kickoffAt == null
                        ? AppColors.text.withValues(alpha: 0.4)
                        : AppColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _Field(controller: _venueController, hintText: 'Venue (optional)'),
            const SizedBox(height: 10),
            _Field(
              controller: _feeController,
              hintText: 'Fee per player (optional)',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 18),
            BlocBuilder<MatchBloc, MatchState>(
              builder: (context, state) {
                final isSubmitting = state is MatchSubmitting;
                return SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.bg,
                      disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.bg,
                            ),
                          )
                        : Text(
                            'Create match',
                            style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hintText,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
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
