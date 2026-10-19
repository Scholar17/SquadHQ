import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:squad_hq/core/splash/kickoff_splash.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget app({required bool loaded}) => MaterialApp(
    home: KickoffSplash(loaded: loaded, child: const Text('The app')),
  );

  /// The kick, then the fade.
  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Dribbles while loading, kicks once loaded, then goes', (tester) async {
    await tester.pumpWidget(app(loaded: false));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Warming up…'), findsOneWidget);

    await tester.pumpWidget(app(loaded: true));
    await tester.pump();
    expect(find.text('Kick off!'), findsOneWidget);

    await finish(tester);
    expect(find.text('Kick off!'), findsNothing);
    expect(find.text('The app'), findsOneWidget);
  });

  testWidgets('Already loaded: still runs a moment before the kick', (tester) async {
    await tester.pumpWidget(app(loaded: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Warming up…'), findsOneWidget);

    await tester.pump(KickoffSplash.minRun);
    expect(find.text('Kick off!'), findsOneWidget);
  });

  testWidgets('A stalled load kicks anyway after the longest wait', (tester) async {
    await tester.pumpWidget(app(loaded: false));
    await tester.pump(KickoffSplash.maxWait);
    await tester.pump();
    expect(find.text('Kick off!'), findsOneWidget);

    await finish(tester);
    expect(find.text('Kick off!'), findsNothing);
  });
}
