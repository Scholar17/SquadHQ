import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/widgets/sticky_action_sheet.dart';
import '../../../squad/presentation/widgets/squad_widgets.dart';
import '../../../venue/domain/entities/venue.dart';
import '../../../venue/domain/usecases/get_team_venues.dart';
import '../../../venue/presentation/widgets/venue_picker_sheet.dart';
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
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
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
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
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
  /// A saved venue (052), or — on a match from before them — a typed one
  /// ([_venueId] null). Picked from [VenuePicker].
  late String? _venueId = widget.initial?.venueId;
  late String? _venueName = widget.initial?.venue;

  /// The venue step is showing in place of the form — same sheet, so
  /// sheets never stack. The fields keep what was typed.
  bool _choosingVenue = false;

  /// The team's saved venues, most recently used first — the first few
  /// show as one-tap chips under the Venue field, since most matches are
  /// at the same pitches. Empty until loaded (or if loading fails).
  List<Venue> _venues = const [];
  static const _quickVenues = 3;
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
  void initState() {
    super.initState();
    _loadVenues();
  }

  /// Also after the venue step, which may have added or renamed one.
  Future<void> _loadVenues() async {
    final result = await sl<GetTeamVenues>()(widget.teamId);
    if (!mounted) return;
    result.fold((_) {}, (venues) => setState(() => _venues = venues));
  }

  void _selectVenue(Venue? venue) => setState(() {
        _venueId = venue?.id;
        _venueName = venue?.name;
      });

  @override
  void dispose() {
    _opponentController.dispose();
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

  /// Under the disabled button, so it's never a silent dead end. Invalid
  /// numbers and a past kick-off already show their own error lines.
  String? get _missingHint {
    final missing = [
      if (_opponentController.text.trim().isEmpty) 'an opponent',
      if (_kickoffAt == null) 'a date & time',
    ];
    if (missing.isEmpty) return null;
    return 'Add ${missing.join(' and ')} to ${_isEditing ? 'save' : 'create the match'}.';
  }

  void _submit() {
    if (!_isValid) return;
    final opponent = _opponentController.text.trim();
    final durationMinutes = (_playHours! * 60).round();
    final playersNeeded = _playersNeeded;
    final initial = widget.initial;
    context.read<MatchBloc>().add(
      initial == null
          ? MatchCreateRequested(
              teamId: widget.teamId,
              opponent: opponent,
              kickoffAt: _kickoffAt!,
              venue: _venueName,
              venueId: _venueId,
              durationMinutes: durationMinutes,
              playersNeeded: playersNeeded,
            )
          : MatchUpdateRequested(
              matchId: initial.id,
              opponent: opponent,
              kickoffAt: _kickoffAt!,
              venue: _venueName,
              venueId: _venueId,
              durationMinutes: durationMinutes,
              playersNeeded: playersNeeded,
            ),
    );
  }

  void _pickVenue() {
    FocusScope.of(context).unfocus();
    setState(() => _choosingVenue = true);
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
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, ?current],
        ),
        child: _choosingVenue
            ? VenuePicker(
                key: const ValueKey('venue'),
                teamId: widget.teamId,
                selectedId: _venueId,
                onChosen: (venue) {
                  _selectVenue(venue);
                  setState(() => _choosingVenue = false);
                  _loadVenues();
                },
                onBack: () {
                  setState(() => _choosingVenue = false);
                  _loadVenues();
                },
              )
            : _buildForm(),
      ),
    );
  }

  /// The fields scroll when the keyboard leaves too little room; the
  /// button stays pinned above it.
  Widget _buildForm() {
    return StickyActionSheet(
      key: const ValueKey('form'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      action: BlocBuilder<MatchBloc, MatchState>(
        builder: (context, state) {
          final isSubmitting = state is MatchSubmitting;
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isSubmitting || !_isValid ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onDark,
                disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.onDark),
                    )
                  : Text(
                      _isEditing ? 'Save changes' : 'Create match',
                      style: AppTextStyles.title(size: 14, color: AppColors.onDark),
                    ),
            ),
          );
        },
      ),
      footer: switch (_missingHint) {
        final hint? => Text(
            hint,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 12, color: AppColors.textMuted),
          ),
        null => null,
      },
      children: [
        Text(_isEditing ? 'Edit match' : 'New match', style: AppTextStyles.title(size: 18)),
        const SizedBox(height: 16),
        _Field(
          controller: _opponentController,
          hintText: 'Opponent',
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: AppRadius.pill,
          onTap: _pickKickoff,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadius.pill,
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
                color: _kickoffAt == null ? AppColors.textMuted : AppColors.text,
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
        InkWell(
          borderRadius: AppRadius.pill,
          onTap: _pickVenue,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            padding: const EdgeInsets.only(left: 18, right: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: AppRadius.pill,
              border: Border.all(color: AppColors.text.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _venueName ?? 'Venue (optional)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: _venueName == null ? AppColors.textMuted : AppColors.text,
                    ),
                  ),
                ),
                Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        if (_venues.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final venue in _venues.take(_quickVenues)) ...[
                  SquadChoiceChip(
                    label: venue.name,
                    icon: Icons.place_outlined,
                    selected: venue.id == _venueId,
                    // Tapping the picked one again clears it.
                    onTap: () => _selectVenue(venue.id == _venueId ? null : venue),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
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
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hintText, required this.onChanged});

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: AppColors.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18),
          border: OutlineInputBorder(
            borderRadius: AppRadius.pill,
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
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.only(left: 18, right: 4),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.pill,
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
                  color: AppColors.textMuted,
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
                  style: AppTextStyles.title(size: 16),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: hintText,
                    hintStyle: AppTextStyles.body(size: 12, color: AppColors.textMuted),
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
