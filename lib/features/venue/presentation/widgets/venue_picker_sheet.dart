import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/venue.dart';
import '../../domain/usecases/get_team_venues.dart';
import 'venue_form_sheet.dart';

/// What the venue picker came back with: a venue, or none ("No venue").
typedef VenueChoice = ({Venue? venue});

/// The new/edit match form's venue: [teamId]'s saved venues, most recently
/// used first, with a search, an edit button on each and "+ Add new
/// venue". Null when closed without choosing.
Future<VenueChoice?> showVenuePicker(
  BuildContext context, {
  required String teamId,
  String? selectedId,
}) {
  return showModalBottomSheet<VenueChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _VenuePickerSheet(teamId: teamId, selectedId: selectedId),
  );
}

class _VenuePickerSheet extends StatefulWidget {
  const _VenuePickerSheet({required this.teamId, this.selectedId});

  final String teamId;
  final String? selectedId;

  @override
  State<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends State<_VenuePickerSheet> {
  final _searchController = TextEditingController();
  List<Venue>? _venues;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final result = await sl<GetTeamVenues>()(widget.teamId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _error = failure.message),
      (venues) => setState(() => _venues = venues),
    );
  }

  Future<void> _addNew() async {
    final venue = await showVenueForm(
      context,
      teamId: widget.teamId,
      initial: null,
    );
    // Picked as soon as it's saved.
    if (venue != null && mounted) Navigator.of(context).pop((venue: venue));
  }

  /// Edited in place: the list shows the change, and nothing's picked.
  Future<void> _edit(Venue venue) async {
    final saved = await showVenueForm(context, teamId: widget.teamId, initial: venue);
    if (saved == null || !mounted) return;
    setState(() {
      _venues = [
        for (final existing in _venues ?? const <Venue>[]) existing.id == saved.id ? saved : existing,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final venues = [
      for (final venue in _venues ?? const <Venue>[])
        if (query.isEmpty || venue.name.toLowerCase().contains(query)) venue,
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Venue', style: AppTextStyles.title(size: 18))),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if ((_venues?.length ?? 0) > 5) ...[
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search venues',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: AppColors.card,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.pill,
                        borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Flexible(
                child: switch ((_venues, _error)) {
                  (_, final String error) => _Message(
                      text: error,
                      action: TextButton(onPressed: _load, child: const Text('Try again')),
                    ),
                  (null, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    ),
                  _ => ListView(
                      shrinkWrap: true,
                      children: [
                        if (widget.selectedId != null)
                          _VenueTile(
                            icon: Icons.block_rounded,
                            title: 'No venue',
                            onTap: () => Navigator.of(context).pop((venue: null)),
                          ),
                        for (final venue in venues)
                          _VenueTile(
                            icon: Icons.place_outlined,
                            title: venue.name,
                            subtitle: venue.notes,
                            selected: venue.id == widget.selectedId,
                            onTap: () => Navigator.of(context).pop((venue: venue)),
                            onEdit: () => _edit(venue),
                          ),
                        if (venues.isEmpty)
                          _Message(
                            text: query.isEmpty
                                ? 'No saved venues yet — add the first one.'
                                : 'No venue called "${_searchController.text.trim()}".',
                          ),
                      ],
                    ),
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add new venue'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: const StadiumBorder(),
                  foregroundColor: AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.onEdit,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// Opens the venue form; none for "No venue".
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.lg,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? AppColors.accent700 : AppColors.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                  ),
                  if (subtitle case final subtitle?)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(size: 12, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_rounded, color: AppColors.accent700),
            if (onEdit case final onEdit?)
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, size: 19, color: AppColors.textMuted),
                tooltip: 'Edit $title',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(size: 13, color: AppColors.textMuted),
          ),
          ?action,
        ],
      ),
    );
  }
}
