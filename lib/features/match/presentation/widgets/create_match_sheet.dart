import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/match.dart' as match_entity;
import '../bloc/match_bloc.dart';
import '../bloc/match_event.dart';
import '../bloc/match_state.dart';
import '../match_formatting.dart';

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
    builder: (_) => _MatchFormSheet(teamId: teamId),
  );
}

/// Same form as [showCreateMatchSheet], prefilled with [match] — opened
/// from the Match tab's "Edit details". `update_match`
/// (supabase/sql/007_match_rsvps_and_actions.sql) is admin-only too.
Future<void> showEditMatchSheet(BuildContext context, {required match_entity.Match match}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _MatchFormSheet(teamId: match.teamId, initial: match),
  );
}

class _MatchFormSheet extends StatefulWidget {
  const _MatchFormSheet({required this.teamId, this.initial});

  final String teamId;

  /// The match being edited, or null when creating a new one.
  final match_entity.Match? initial;

  @override
  State<_MatchFormSheet> createState() => _MatchFormSheetState();
}

class _MatchFormSheetState extends State<_MatchFormSheet> {
  late final _opponentController = TextEditingController(text: widget.initial?.opponent);
  late final _venueController = TextEditingController(text: widget.initial?.venue);
  late DateTime? _kickoffAt = widget.initial?.kickoffAt.toLocal();
  late final _playTimeController = TextEditingController(
    text: _formatHours(
      (widget.initial?.durationMinutes ?? match_entity.Match.defaultDurationMinutes) / 60,
    ),
  );

  late final _playersNeededController = TextEditingController(
    text: widget.initial?.playersNeeded?.toString(),
  );

  bool get _isEditing => widget.initial != null;

  /// Players needed is optional — blank means no target; otherwise 2–50
  /// (the `players_needed` check in supabase/sql/014).
  static const _minPlayers = 2;
  static const _maxPlayers = 50;

  bool get _playersNeededValid {
    final text = _playersNeededController.text.trim();
    if (text.isEmpty) return true;
    final players = int.tryParse(text);
    return players != null && players >= _minPlayers && players <= _maxPlayers;
  }

  int? get _playersNeeded => int.tryParse(_playersNeededController.text.trim());

  void _stepPlayers(int delta) {
    final current = _playersNeeded ?? (delta > 0 ? _minPlayers - 1 : _minPlayers);
    final next = (current + delta).clamp(_minPlayers, _maxPlayers);
    setState(() => _playersNeededController.text = '$next');
  }

  /// Play time bounds, matching the `duration_minutes` check in
  /// supabase/sql/009 (15 minutes to 12 hours); +/- step by half an hour.
  static const _minHours = 0.25;
  static const _maxHours = 12.0;
  static const _stepHours = 0.5;

  static String _formatHours(double hours) =>
      hours == hours.roundToDouble() ? hours.toInt().toString() : '$hours';

  double? get _playHours {
    final hours = double.tryParse(_playTimeController.text.trim());
    return hours != null && hours >= _minHours && hours <= _maxHours ? hours : null;
  }

  void _stepPlayTime(double delta) {
    final current = double.tryParse(_playTimeController.text.trim()) ?? 1;
    // Snap to the half-hour grid, so 1.2 + ½ goes to 1.5, not 1.7.
    final snapped = delta > 0
        ? (current / _stepHours).floor() * _stepHours + _stepHours
        : (current / _stepHours).ceil() * _stepHours - _stepHours;
    final next = snapped.clamp(_stepHours, _maxHours);
    setState(() => _playTimeController.text = _formatHours(next));
  }

  @override
  void dispose() {
    _opponentController.dispose();
    _venueController.dispose();
    _playTimeController.dispose();
    _playersNeededController.dispose();
    super.dispose();
  }

  Future<void> _pickKickoff() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = _kickoffAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(today) ? now : current,
      firstDate: today,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
      // Always AM/PM, like the rest of the app. A phone set to 24-hour time
      // otherwise gets a 24-hour dial, where the outer "7" means 07:00 — an
      // easy way to schedule a 7 PM match for 7 in the morning.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _kickoffAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// A match can't kick off in the past — it would skip straight to
  /// history (and Man of the Match voting) with no RSVPs.
  bool get _kickoffInFuture => _kickoffAt?.isAfter(DateTime.now()) ?? false;

  bool get _isValid =>
      _opponentController.text.trim().isNotEmpty &&
      _kickoffInFuture &&
      _playHours != null &&
      _playersNeededValid;

  void _submit() {
    if (!_isValid) return;
    final opponent = _opponentController.text.trim();
    final venue = _venueController.text.trim().isEmpty ? null : _venueController.text.trim();
    final durationMinutes = (_playHours! * 60).round();
    final playersNeeded = _playersNeeded;
    final initial = widget.initial;
    context.read<MatchBloc>().add(
      initial == null
          ? MatchCreateRequested(
              teamId: widget.teamId,
              opponent: opponent,
              kickoffAt: _kickoffAt!,
              venue: venue,
              durationMinutes: durationMinutes,
              playersNeeded: playersNeeded,
            )
          : MatchUpdateRequested(
              matchId: initial.id,
              opponent: opponent,
              kickoffAt: _kickoffAt!,
              venue: venue,
              durationMinutes: durationMinutes,
              playersNeeded: playersNeeded,
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
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        // Scrolls when the keyboard leaves too little room.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditing ? 'Edit match' : 'New match', style: AppTextStyles.heading(size: 18)),
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
                    border: Border.all(
                      color: _kickoffAt != null && !_kickoffInFuture
                          ? AppColors.accent700
                          : AppColors.text.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    _kickoffAt == null ? 'Date & time' : formatMatchDateTime(_kickoffAt!),
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
              if (_kickoffAt != null && !_kickoffInFuture)
                Padding(
                  padding: const EdgeInsets.only(left: 18, top: 4),
                  child: Text(
                    'Kick-off must be later than now — check AM / PM.',
                    style: AppTextStyles.body(size: 11.5, color: AppColors.accent700),
                  ),
                ),
              const SizedBox(height: 10),
              _Field(controller: _venueController, hintText: 'Venue (optional)'),
              const SizedBox(height: 10),
              _StepperField(
                label: 'Play time',
                unit: 'hr',
                controller: _playTimeController,
                decimal: true,
                isValid: _playHours != null,
                errorText: 'Enter between 0.25 and 12 hours',
                minusTooltip: 'Half an hour less',
                plusTooltip: 'Half an hour more',
                onChanged: () => setState(() {}),
                onMinus: () => _stepPlayTime(-_stepHours),
                onPlus: () => _stepPlayTime(_stepHours),
              ),
              const SizedBox(height: 10),
              _StepperField(
                label: 'Players needed',
                unit: '',
                hintText: 'optional',
                controller: _playersNeededController,
                isValid: _playersNeededValid,
                errorText: 'Enter between $_minPlayers and $_maxPlayers players, or leave it blank',
                minusTooltip: 'One player fewer',
                plusTooltip: 'One player more',
                onChanged: () => setState(() {}),
                onMinus: () => _stepPlayers(-1),
                onPlus: () => _stepPlayers(1),
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
                              _isEditing ? 'Save changes' : 'Create match',
                              style: AppTextStyles.heading(size: 14, color: AppColors.bg),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: TextField(
        controller: controller,
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

/// A number you can type or step with − / + — play time (hours) and players
/// needed.
class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.unit,
    required this.controller,
    required this.isValid,
    required this.errorText,
    required this.minusTooltip,
    required this.plusTooltip,
    required this.onChanged,
    required this.onMinus,
    required this.onPlus,
    this.decimal = false,
    this.hintText,
  });

  final String label;
  final String unit;
  final TextEditingController controller;
  final bool isValid;
  final String errorText;
  final String minusTooltip;
  final String plusTooltip;
  final VoidCallback onChanged;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool decimal;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.only(left: 18, right: 4),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isValid ? AppColors.text.withValues(alpha: 0.16) : AppColors.accent700,
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: AppTextStyles.body(
                  size: 14,
                  weight: FontWeight.w600,
                  color: AppColors.text.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onMinus,
                icon: const Icon(Icons.remove_rounded),
                tooltip: minusTooltip,
              ),
              SizedBox(
                width: 52,
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(decimal: decimal),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(decimal ? r'[\d.]' : r'\d')),
                  ],
                  style: AppTextStyles.heading(size: 16),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: hintText,
                    hintStyle: AppTextStyles.body(
                      size: 12,
                      color: AppColors.text.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Text(unit, style: AppTextStyles.body(size: 14, weight: FontWeight.w700)),
              IconButton(
                onPressed: onPlus,
                icon: const Icon(Icons.add_rounded),
                tooltip: plusTooltip,
              ),
            ],
          ),
        ),
        if (!isValid)
          Padding(
            padding: const EdgeInsets.only(left: 18, top: 4),
            child: Text(
              errorText,
              style: AppTextStyles.body(size: 11.5, color: AppColors.accent700),
            ),
          ),
      ],
    );
  }
}
