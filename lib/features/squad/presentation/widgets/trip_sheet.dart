import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/trip.dart';
import '../../domain/repositories/squad_repository.dart';
import '../bloc/squad_ledger_bloc.dart';
import '../squad_formatting.dart';
import 'squad_widgets.dart';

/// An admin sets up a trip ([editing] null) or changes one: its name,
/// dates and who's going (everyone, to start).
Future<void> showTripSheet(
  BuildContext context, {
  required String teamId,
  required String me,
  Trip? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: AppRadius.sheet,
    ),
    builder: (_) => _TripSheet(teamId: teamId, me: me, editing: editing),
  );
}

class _TripSheet extends StatefulWidget {
  const _TripSheet({required this.teamId, required this.me, this.editing});

  final String teamId;
  final String me;
  final Trip? editing;

  @override
  State<_TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends State<_TripSheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late DateTimeRange? _dates = switch (widget.editing) {
    final trip? => DateTimeRange(start: trip.startsOn, end: trip.endsOn),
    null => null,
  };

  /// Who's going; null = everyone (not yet touched).
  late Set<String>? _going = widget.editing?.memberIds.toSet();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _dates ?? DateTimeRange(start: today, end: today.add(const Duration(days: 2))),
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dates = picked);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SquadLedgerBloc, SquadLedgerState>(
      listenWhen: (previous, current) =>
          current is SquadLedgerFailure ||
          (previous is SquadLedgerSubmitting && current is SquadLedgerLoaded),
      listener: (context, state) {
        if (state case SquadLedgerFailure(:final message)) {
          _snack(message);
        } else {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final members = state.ledger?.members ?? const [];
        final going = _going ?? {for (final m in members) m.profileId};
        final dates = _dates;
        final name = _name.text.trim();
        final canSave = name.isNotEmpty && dates != null && going.length >= 2;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.editing == null ? 'New trip' : 'Edit trip',
                      style: AppTextStyles.heading(size: 20),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              Text('NAME', style: AppTextStyles.label(color: squadMuted)),
              const SizedBox(height: 4),
              TextField(
                key: const ValueKey('trip-name'),
                controller: _name,
                autofocus: widget.editing == null,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.body(size: 15, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Chiang Mai',
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.sm,
                    borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('DATES', style: AppTextStyles.label(color: squadMuted)),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _pickDates,
                icon: const Icon(Icons.date_range_rounded, size: 18),
                label: Text(
                  dates == null
                      ? 'Pick the dates'
                      : '${formatTripDates(dates.start, dates.end)} · '
                            '${dates.duration.inDays + 1} '
                            '${dates.duration.inDays == 0 ? 'day' : 'days'}',
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(46),
                  side: BorderSide(color: AppColors.text.withValues(alpha: 0.18)),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.sm),
                ),
              ),
              const SizedBox(height: 14),
              Text("WHO'S GOING · ${going.length}", style: AppTextStyles.label(color: squadMuted)),
              for (final member in members)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.accentFill,
                  secondary: SquadAvatar(
                    initial: member.initial,
                    photoUrl: member.avatarUrl,
                    size: 30,
                  ),
                  title: Text(
                    member.profileId == widget.me ? '${member.name} (you)' : member.name,
                    style: AppTextStyles.body(size: 14, weight: FontWeight.w600),
                  ),
                  value: going.contains(member.profileId),
                  onChanged: (_) => setState(() {
                    final next = {...going};
                    if (!next.remove(member.profileId)) next.add(member.profileId);
                    _going = next;
                  }),
                ),
              const SizedBox(height: 4),
              Text(
                'People on the trip add what they paid. When it ends, an admin '
                'closes it and everyone settles up for the trip on its own.',
                style: AppTextStyles.body(size: 12, color: squadMuted),
              ),
              const SizedBox(height: 16),
              SquadPrimaryButton(
                label: widget.editing == null ? 'Create trip' : 'Save changes',
                isLoading: state is SquadLedgerSubmitting,
                onPressed: !canSave
                    ? null
                    : () => context.read<SquadLedgerBloc>().add(
                        TripSaveRequested(
                          TripDraft(
                            id: widget.editing?.id,
                            teamId: widget.teamId,
                            name: name,
                            startsOn: dates.start,
                            endsOn: dates.end,
                            memberIds: [
                              for (final m in members)
                                if (going.contains(m.profileId)) m.profileId,
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
