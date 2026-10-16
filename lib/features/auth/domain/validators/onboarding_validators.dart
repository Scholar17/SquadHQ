/// Pure validation rules for the "One last thing" onboarding form.
/// Kept outside the widget tree so they're unit-testable without pumping
/// a widget.
abstract final class OnboardingValidators {
  /// Someone already has it (any case, 049_mentions.sql) — only the server
  /// can tell, so it's shown under the field after a save fails.
  static const usernameTaken = 'That mention name is taken. Try another one.';

  /// The name the squad sees — spaces and names others have are fine.
  static String? nameError(String name) => switch (name.trim().length) {
        0 => 'Enter your name.',
        > 40 => 'Keep it to 40 characters.',
        _ => null,
      };

  /// Thai mobile numbers are 9 digits after the +66 country code
  /// (e.g. 81 234 5678).
  static String? phoneError(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter the number the squad can reach you on.';
    if (digits.length != 9) return 'Enter a 9-digit mobile number.';
    return null;
  }

  static String? usernameError(String username) {
    if (username.isEmpty) return 'Pick a mention name your squad will recognise.';
    if (username.length < 3) return 'Mention name must be at least 3 characters.';
    if (username.length > 20) return 'Mention name must be 20 characters or fewer.';
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(username)) {
      return 'Letters, numbers and underscores only, starting with a letter.';
    }
    return null;
  }
}
