import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/venue.dart';
import '../../domain/usecases/get_team_venues.dart';
import 'venue_form_sheet.dart';

/// The new/edit match form's venue step, shown in place of the form inside
/// the same sheet: [teamId]'s saved venues, most recently used first, with
/// a search, an edit button on each and "+ Add new venue" — which also
/// open in place, so there's only ever one sheet. [onChosen] gets the
/// venue, or null for "No venue"; [onBack] returns without choosing (✕ or
/// the system back).
class VenuePicker extends StatefulWidget {
  const VenuePicker({
    super.key,
    required this.teamId,
    required this.onChosen,
    required this.onBack,
    this.selectedId,
  });

  final String teamId;
  final String? selectedId;
  final ValueChanged<Venue?> onChosen;
  final VoidCallback onBack;

  @override
  State<VenuePicker> createState() => _VenuePickerState();
}

class _VenuePickerState extends State<VenuePicker> {
  final _searchController = TextEditingController();
  List<Venue>? _venues;
  String? _error;

  /// The venue form open in place of the list: adding (initial null) or
  /// editing. Null shows the list.
  ({Venue? initial})? _form;

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

  void _onSaved(Venue saved) {
    // A new venue is picked as soon as it's saved; an edited one updates
    // the list, and nothing's picked.
    if (_form?.initial == null) return widget.onChosen(saved);
    setState(() {
      _form = null;
      _venues = [
        for (final existing in _venues ?? const <Venue>[]) existing.id == saved.id ? saved : existing,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    // The system back steps back too: form → list → the match form.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_form != null) {
          setState(() => _form = null);
        } else {
          widget.onBack();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.bottomCenter,
          children: [...previous, ?current],
        ),
        child: form == null
            ? KeyedSubtree(key: const ValueKey('list'), child: _buildList(context))
            : VenueForm(
                key: ValueKey(form.initial?.id ?? 'new'),
                teamId: widget.teamId,
                initial: form.initial,
                onSaved: _onSaved,
                onClose: () => setState(() => _form = null),
              ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
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
                    onPressed: widget.onBack,
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
                            onTap: () => widget.onChosen(null),
                          ),
                        for (final venue in venues)
                          _VenueTile(
                            icon: Icons.place_outlined,
                            title: venue.name,
                            subtitle: venue.notes,
                            selected: venue.id == widget.selectedId,
                            onTap: () => widget.onChosen(venue),
                            onEdit: () => setState(() => _form = (initial: venue)),
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
                onPressed: () => setState(() => _form = (initial: null)),
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
