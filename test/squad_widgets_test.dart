import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:squad_hq/features/squad/presentation/widgets/squad_widgets.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // The squad Home hero puts two of these side by side; on a 320px phone
  // each gets ~120px.
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('Hero pill buttons fit side by side at ${width.toInt()}px', (tester) async {
      tester.view
        ..physicalSize = Size(width, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              // The page gutter plus the hero card's padding.
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: Row(
                children: [
                  Expanded(
                    child: HeroPillButton(label: 'Settle up', onPressed: () {}),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HeroPillButton(
                      label: 'Add expense',
                      icon: Icons.add_rounded,
                      light: false,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
