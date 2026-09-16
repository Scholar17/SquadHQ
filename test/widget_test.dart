import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:squad_hq/app.dart';
import 'package:squad_hq/core/di/injection_container.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    // Avoid network font fetches in the test environment.
    GoogleFonts.config.allowRuntimeFetching = false;
    await initTestSupabase();
    await initDependencies();
  });

  testWidgets('shows the login screen with both social sign-in doors',
      (tester) async {
    await tester.pumpWidget(const SquadHqApp());
    await tester.pump();

    expect(find.text('Continue with Facebook'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Every match,\nsorted.'), findsOneWidget);
  });
}
