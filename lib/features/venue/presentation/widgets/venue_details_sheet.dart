import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../wallet/presentation/wallet_formatting.dart';
import '../../../weather/presentation/widgets/kickoff_conditions.dart';
import '../../domain/entities/venue.dart';
import '../../domain/usecases/archive_venue.dart';
import '../../domain/usecases/get_venue.dart';
import 'venue_form_sheet.dart';

/// A match's venue, tapped from the match: photo, notes, price and "Open
/// in Google Maps". Team admins ([canManage]) can edit it or take it off
/// the list. With [kickoffAt] (the match it was opened from), the
/// forecast there for kickoff.
Future<void> showVenueDetails(
  BuildContext context, {
  required String venueId,
  required bool canManage,
  DateTime? kickoffAt,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheet),
    builder: (_) => _VenueDetailsSheet(
      venueId: venueId,
      canManage: canManage,
      kickoffAt: kickoffAt,
    ),
  );
}

class _VenueDetailsSheet extends StatefulWidget {
  const _VenueDetailsSheet({required this.venueId, required this.canManage, this.kickoffAt});

  final String venueId;
  final bool canManage;
  final DateTime? kickoffAt;

  @override
  State<_VenueDetailsSheet> createState() => _VenueDetailsSheetState();
}

class _VenueDetailsSheetState extends State<_VenueDetailsSheet> {
  Venue? _venue;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final result = await sl<GetVenue>()(widget.venueId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() => _error = failure.message),
      (venue) => setState(() => _venue = venue),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openMaps(String url) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) _snack("Couldn't open Google Maps.");
  }

  Future<void> _edit(Venue venue) async {
    final saved = await showVenueForm(context, teamId: venue.teamId, initial: venue);
    if (saved != null && mounted) setState(() => _venue = saved);
  }

  Future<void> _archive(Venue venue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
        title: Text('Remove ${venue.name}?', style: AppTextStyles.heading(size: 20)),
        content: Text(
          "It won't be offered for new matches. Matches already at it keep showing it.",
          style: AppTextStyles.body(size: 13.5, color: AppColors.textSubtle),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: AppTextStyles.body(size: 14, weight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Remove',
              style: AppTextStyles.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.accent700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result = await sl<ArchiveVenue>()(venue.id);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold((failure) => _snack(failure.message), (_) {
      // Shown under the sheet, which closes.
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${venue.name} removed from your venues.')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final venue = _venue;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: switch ((venue, _error)) {
            (_, final String error) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(size: 13, color: AppColors.textMuted),
                  ),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            (null, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ),
            (final Venue venue, _) => _details(venue),
          },
        ),
      ),
    );
  }

  Widget _details(Venue venue) {
    final mapsUrl = venue.mapsUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Closing comes first, above the photo, where it's found at once.
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ),
        if (venue.photoUrl case final photoUrl?) ...[
          ClipRRect(
            borderRadius: AppRadius.lg,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: AppColors.card),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(venue.name, style: AppTextStyles.heading(size: 24)),
        if (venue.archived) ...[
          const SizedBox(height: 4),
          Text(
            "Removed from your team's venues",
            style: AppTextStyles.body(size: 12, color: AppColors.textMuted),
          ),
        ],
        if ((venue.latitude, venue.longitude, widget.kickoffAt)
            case (final latitude?, final longitude?, final kickoffAt?)
            when kickoffAt.isAfter(DateTime.now())) ...[
          KickoffConditions(
            latitude: latitude,
            longitude: longitude,
            kickoffAt: kickoffAt,
          ),
          // Open-Meteo and WAQI are credited in each tile's tap-for-details.
        ],
        if (venue.pricePerHour case final price?) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                '${price == price.roundToDouble() ? formatBaht(price) : formatBahtExact(price)} '
                'per hour',
                style: AppTextStyles.body(size: 13.5, weight: FontWeight.w600),
              ),
            ],
          ),
        ],
        if (venue.notes case final notes?) ...[
          const SizedBox(height: 10),
          // The icon marks it as a note, so a short one ("Bangkapi") isn't
          // read as the venue's address.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 18, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  notes,
                  style: AppTextStyles.body(size: 13.5, color: AppColors.textSubtle, height: 1.45),
                ),
              ),
            ],
          ),
        ],
        if (mapsUrl != null) ...[
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _openMaps(mapsUrl),
            icon: const Icon(Icons.map_outlined),
            label: Text(
              'Open in Google Maps',
              style: AppTextStyles.title(size: 14, color: AppColors.onDark),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onDark,
              minimumSize: const Size(0, 48),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
          ),
        ],
        if (widget.canManage) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _edit(venue),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: const StadiumBorder(),
                    foregroundColor: AppColors.text,
                  ),
                  child: const Text('Edit venue'),
                ),
              ),
              if (!venue.archived) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _archive(venue),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                      foregroundColor: AppColors.accent700,
                    ),
                    child: const Text('Remove from list'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
