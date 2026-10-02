import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'package:squad_hq/features/match/domain/entities/match.dart';
import 'package:squad_hq/features/match/domain/entities/match_history.dart';
import 'package:squad_hq/features/team_membership/presentation/widgets/timezone_picker_sheet.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tz_data.initializeTimeZones();
  });

  // Finishes 22:00 UTC on 20 Sep: 05:00 on the 21st in Bangkok (UTC+7),
  // 18:00 on the 20th in New York (UTC-4 in September).
  final pastMatch = PastMatch(
    match: Match(
      id: 'm',
      teamId: 't',
      opponent: 'X',
      kickoffAt: DateTime.utc(2026, 9, 20, 21),
    ),
  );

  test('MOTM voting closes at midnight in the team time zone', () {
    // Bangkok: midnight starting 22 Sep local = 21 Sep 17:00 UTC.
    expect(
      const MatchHistory(timezone: 'Asia/Bangkok').motmVotingClosesAt(pastMatch),
      DateTime.utc(2026, 9, 21, 17),
    );
    // New York: midnight starting 21 Sep local (EDT) = 21 Sep 04:00 UTC.
    expect(
      const MatchHistory(timezone: 'America/New_York').motmVotingClosesAt(pastMatch),
      DateTime.utc(2026, 9, 21, 4),
    );
    // Yangon (UTC+6:30): midnight starting 22 Sep local = 21 Sep 17:30 UTC.
    expect(
      const MatchHistory(timezone: 'Asia/Yangon').motmVotingClosesAt(pastMatch),
      DateTime.utc(2026, 9, 21, 17, 30),
    );
  });

  test('An unknown team time zone falls back to UTC+7', () {
    expect(
      const MatchHistory(timezone: 'Not/AZone').motmVotingClosesAt(pastMatch),
      DateTime.utc(2026, 9, 21, 17),
    );
  });

  test('UTC offset labels', () {
    expect(utcOffsetLabel('Asia/Bangkok'), 'UTC+7');
    expect(utcOffsetLabel('Asia/Yangon'), 'UTC+6:30');
    expect(utcOffsetLabel('Nowhere/Land'), isNull);
  });

  testWidgets('The time zone picker searches and returns the picked zone', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                picked = await showTimezonePickerSheet(context, current: 'Asia/Bangkok'),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'yangon');
    await tester.pumpAndSettle();
    expect(find.text('Asia/Yangon'.replaceAll('_', ' ')), findsOneWidget);
    expect(find.text('UTC+6:30'), findsOneWidget);

    await tester.tap(find.text('Asia/Yangon'));
    await tester.pumpAndSettle();
    expect(picked, 'Asia/Yangon');
  });
}
