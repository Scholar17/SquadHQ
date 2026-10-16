import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/features/auth/domain/validators/onboarding_validators.dart';
import 'package:squad_hq/features/auth/presentation/widgets/username_input_formatter.dart';

void main() {
  const formatter = UsernameInputFormatter();

  TextEditingValue type(String text) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
      );

  test('a typed space becomes an underscore, cursor where it was', () {
    final value = type('aung ko');
    expect(value.text, 'aung_ko');
    expect(value.selection.baseOffset, 7);
    expect(OnboardingValidators.usernameError(value.text), isNull);
  });

  test('pasted tabs and repeated spaces each become one underscore', () {
    expect(type('aung\tko  thu').text, 'aung_ko__thu');
  });

  test('text without spaces is left alone', () {
    final value = type('AungKo');
    expect(value.text, 'AungKo');
  });

  test('a leading space still needs a letter first', () {
    expect(OnboardingValidators.usernameError(type(' aung').text), isNotNull);
  });
}
