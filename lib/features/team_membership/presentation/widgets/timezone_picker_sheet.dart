import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// "UTC+7", "UTC+5:30", "UTC-3" — [zone]'s offset right now, or null if
/// the zone isn't in the time zone database.
String? utcOffsetLabel(String zone) {
  try {
    final offset = tz.TZDateTime.now(tz.getLocation(zone)).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final minutes = offset.inMinutes.abs();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return 'UTC$sign$hours${rest == 0 ? '' : ':${rest.toString().padLeft(2, '0')}'}';
  } on tz.LocationNotFoundException {
    return null;
  }
}

/// A searchable list of IANA time zones; resolves to the picked name, or
/// null if dismissed.
Future<String?> showTimezonePickerSheet(BuildContext context, {required String current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TimezonePicker(current: current),
  );
}

class _TimezonePicker extends StatefulWidget {
  const _TimezonePicker({required this.current});

  final String current;

  @override
  State<_TimezonePicker> createState() => _TimezonePickerState();
}

class _TimezonePickerState extends State<_TimezonePicker> {
  // Region/City names only — skips legacy aliases like "EST5EDT".
  late final List<String> _zones = tz.timeZoneDatabase.locations.keys
      .where((zone) => zone.contains('/') && !zone.startsWith('Etc/'))
      .toList()
    ..sort();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase().replaceAll(' ', '_');
    final matches = [
      for (final zone in _zones)
        if (zone.toLowerCase().contains(query)) zone,
    ];
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Team time zone', style: AppTextStyles.heading(size: 18)),
            const SizedBox(height: 4),
            Text(
              'Decides when match day ends for Man of the Match voting. Times '
              "still show in each player's own phone time.",
              style: AppTextStyles.body(
                size: 12,
                color: AppColors.text.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                hintText: 'Search a city, e.g. Bangkok',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.neutral100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: BorderSide(color: AppColors.text.withValues(alpha: 0.16)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'No time zone matches "$_query"',
                        style: AppTextStyles.body(
                          size: 13,
                          color: AppColors.text.withValues(alpha: 0.55),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final zone = matches[index];
                        final selected = zone == widget.current;
                        return ListTile(
                          title: Text(
                            zone.replaceAll('_', ' '),
                            style: AppTextStyles.body(
                              size: 14,
                              weight: selected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            utcOffsetLabel(zone) ?? '',
                            style: AppTextStyles.body(
                              size: 12,
                              color: AppColors.text.withValues(alpha: 0.55),
                            ),
                          ),
                          trailing: selected
                              ? const Icon(Icons.check_rounded, color: AppColors.accent)
                              : null,
                          onTap: () => Navigator.of(context).pop(zone),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
