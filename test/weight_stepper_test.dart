import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/squad/presentation/widgets/sheet_parts.dart';

Future<TextEditingController> pump(WidgetTester tester, {required bool percent, String text = ''}) async {
  final controller = TextEditingController(text: text);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: WeightStepper(controller: controller, percent: percent, name: 'Ko')),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('Percent: + adds 10%, − takes 10% off, never below 0 or above 100', (tester) async {
    final controller = await pump(tester, percent: true, text: '95');
    await tester.tap(find.byTooltip('Increase Ko by 10%'));
    await tester.pump();
    expect(controller.text, '100');
    await tester.tap(find.byTooltip('Decrease Ko by 10%'));
    await tester.pump();
    expect(controller.text, '90');
    controller.text = '5';
    await tester.pump();
    await tester.tap(find.byTooltip('Decrease Ko by 10%'));
    await tester.pump();
    expect(controller.text, '0');
  });

  testWidgets('Shares: steps 1 share, from empty too', (tester) async {
    final controller = await pump(tester, percent: false);
    await tester.tap(find.byTooltip('Increase Ko by 1 share'));
    await tester.pump();
    expect(controller.text, '1');
    await tester.tap(find.byTooltip('Increase Ko by 1 share'));
    await tester.pump();
    expect(controller.text, '2');
  });
}
