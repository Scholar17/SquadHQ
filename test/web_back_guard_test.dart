import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_hq/core/routing/web_back_guard.dart';

void main() {
  late List<MethodCall> navigation;
  late List<MethodCall> platform;

  setUp(() {
    navigation = [];
    platform = [];
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
      ],
    );
    final guard = WebBackGuard.install(router, enabled: true)!;
    addTearDown(() => WidgetsBinding.instance.removeObserver(guard));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  /// What the browser's back button turns into once it pops the guard.
  Future<void> browserBack(WidgetTester tester) async {
    await tester.binding.handlePushRoute('/');
    await tester.pumpAndSettle();
  }

  bool pushedGuard(MethodCall call) =>
      call.method == 'routeInformationUpdated' &&
      (call.arguments as Map)['replace'] == false;

  testWidgets('Puts a guard entry on top of the browser history once the app is up', (tester) async {
    await pumpGuarded(tester);
    expect(navigation.where(pushedGuard), hasLength(1));
  });

  testWidgets('Browser back closes the pushed screen and restores the guard', (tester) async {
    final router = await pumpGuarded(tester);
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
    navigation.clear();

    await browserBack(tester);

    expect(find.text('Home'), findsOneWidget);
    expect(navigation.where(pushedGuard), hasLength(1));
    expect(platform.where((call) => call.method == 'SystemNavigator.pop'), isEmpty);
  });

  testWidgets('Browser back with nothing left to close exits the app', (tester) async {
    await pumpGuarded(tester);

    await browserBack(tester);

    expect(platform.where((call) => call.method == 'SystemNavigator.pop'), hasLength(1));
  });
}
