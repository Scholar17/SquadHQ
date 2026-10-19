import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_hq/core/splash/startup_splash.dart';

void main() {
  Widget app({required bool loaded}) => MaterialApp(
    home: StartupSplash(loaded: loaded, child: const Text('The app')),
  );

  final splash = find.byType(WarmUpScreen);

  /// The fade out.
  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Warms up while loading, then fades into the app', (tester) async {
    await tester.pumpWidget(app(loaded: false));
    await tester.pump(const Duration(seconds: 2));
    expect(splash, findsOneWidget);

    await tester.pumpWidget(app(loaded: true));
    await finish(tester);
    expect(splash, findsNothing);
    expect(find.text('The app'), findsOneWidget);
  });

  testWidgets('Already loaded: still shows a moment first', (tester) async {
    await tester.pumpWidget(app(loaded: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(splash, findsOneWidget);

    await tester.pump(StartupSplash.minRun);
    await finish(tester);
    expect(splash, findsNothing);
  });

  testWidgets('A stalled load goes to the app anyway after the longest wait', (tester) async {
    await tester.pumpWidget(app(loaded: false));
    await tester.pump(StartupSplash.maxWait);
    await finish(tester);
    expect(splash, findsNothing);
  });
}
