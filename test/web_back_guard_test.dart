import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_hq/core/routing/web_back_guard.dart';

void main() {
  late List<MethodCall> navigation;
  late List<MethodCall> platform;
  late List<int> historyMoves;

  setUp(() {
    navigation = [];
    platform = [];
    historyMoves = [];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.navigation, (call) async {
      navigation.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.add(call);
      return null;
    });
  });

  Future<GoRouter> pumpGuarded(WidgetTester tester) async {
    final router = GoRouter(
      // As createAppRouter sets it on web.
      routerNeglect: true,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Home')),
        GoRoute(path: '/detail', builder: (_, _) => const Text('Detail')),
        GoRoute(path: '/other', builder: (_, _) => const Text('Other')),
      ],
    );
    final guard = WebBackGuard.install(
      router,
      fallbackLocation: '/',
      enabled: true,
      historyGo: historyMoves.add,
    )!;
    addTearDown(guard.remove);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  /// What the browser's back button turns into once it pops a guard entry.
  Future<void> browserBack(WidgetTester tester) async {
    await tester.binding.handlePushRoute('/');
    await tester.pumpAndSettle();
  }

  bool pushedGuard(MethodCall call) =>
      call.method == 'routeInformationUpdated' &&
      (call.arguments as Map)['replace'] == false;

  testWidgets('Adds no guard entries until the first tap', (tester) async {
    await pumpGuarded(tester);
    expect(navigation.where(pushedGuard), isEmpty);
  });

  testWidgets('A tap tops the guard entries up to the buffer', (tester) async {
    await pumpGuarded(tester);

    await tester.tapAt(const Offset(10, 10));
    expect(navigation.where(pushedGuard), hasLength(WebBackGuard.bufferSize));

    // Already full: another tap adds nothing.
    navigation.clear();
    await tester.tapAt(const Offset(10, 10));
    expect(navigation.where(pushedGuard), isEmpty);
  });

  testWidgets('Browser back closes the pushed screen without adding an entry', (tester) async {
    final router = await pumpGuarded(tester);
    await tester.tapAt(const Offset(10, 10));
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
    navigation.clear();

    await browserBack(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(navigation.where(pushedGuard), isEmpty);
    expect(platform.where((call) => call.method == 'SystemNavigator.pop'), isEmpty);

    // The next tap replaces the one entry used up.
    await tester.tapAt(const Offset(10, 10));
    expect(navigation.where(pushedGuard), hasLength(1));
  });

  testWidgets('Browser back with nothing left to close goes to the fallback', (tester) async {
    final router = await pumpGuarded(tester);
    router.go('/other');
    await tester.pumpAndSettle();

    await browserBack(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(platform.where((call) => call.method == 'SystemNavigator.pop'), isEmpty);
  });

  testWidgets('Release takes every guard entry off, and its popstate is ignored', (tester) async {
    final router = await pumpGuarded(tester);
    await tester.tapAt(const Offset(10, 10));
    router.push('/detail');
    await tester.pumpAndSettle();

    WebBackGuard.release();
    expect(historyMoves, [-WebBackGuard.bufferSize]);

    navigation.clear();
    await browserBack(tester);
    // Its own popstate: the screen stays, and the entry is pointed back at it.
    expect(find.text('Detail'), findsOneWidget);
    expect(
      navigation.where((call) => call.method == 'routeInformationUpdated' && (call.arguments as Map)['replace'] == true),
      hasLength(1),
    );

    // Nothing left to release.
    WebBackGuard.release();
    expect(historyMoves, hasLength(1));
  });
}
