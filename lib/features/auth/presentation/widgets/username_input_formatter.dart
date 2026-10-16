import 'package:flutter/services.dart';

/// Usernames can't have spaces (they end an @mention) — a typed or pasted
/// space becomes "_" instead of an error: "aung ko" → "aung_ko". One
/// character for one, so the cursor stays put.
class UsernameInputFormatter extends TextInputFormatter {
  const UsernameInputFormatter();

  static final _space = RegExp(r'\s');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (!_space.hasMatch(newValue.text)) return newValue;
    return newValue.copyWith(text: newValue.text.replaceAll(_space, '_'));
  }
}
