import 'package:flutter/material.dart';

/// One full set of the adaptive colours — [light] is the "Organic" design
/// system (ds-styles.css), [dark] the "Midnight pitch" night theme.
///
/// Each token keeps its *role* across themes, not its shade: [card] is the
/// raised surface (cream by day, charcoal by night), [text] the ink on it.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.card,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.divider,
    required this.inverse,
    required this.neutral200,
    required this.neutral300,
    required this.neutral400,
    required this.neutral500,
    required this.neutral600,
    required this.neutral700,
    required this.accent100,
    required this.accent200,
    required this.accent300,
    required this.accent600,
    required this.accent700,
    required this.accent800,
    required this.accent900,
    required this.accent2_100,
    required this.accent2_700,
    required this.accent2_900,
    required this.categoryPlumBg,
    required this.categoryPlum,
    required this.categoryRoseBg,
    required this.categoryRose,
    required this.categoryBlueBg,
    required this.categoryBlue,
    required this.categoryGoldBg,
    required this.categoryGold,
    required this.categoryTealBg,
    required this.categoryTeal,
    required this.shadow,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color card;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color divider;
  final Color inverse;
  final Color neutral200;
  final Color neutral300;
  final Color neutral400;
  final Color neutral500;
  final Color neutral600;
  final Color neutral700;
  final Color accent100;
  final Color accent200;
  final Color accent300;
  final Color accent600;
  final Color accent700;
  final Color accent800;
  final Color accent900;
  final Color accent2_100;
  final Color accent2_700;
  final Color accent2_900;
  final Color categoryPlumBg;
  final Color categoryPlum;
  final Color categoryRoseBg;
  final Color categoryRose;
  final Color categoryBlueBg;
  final Color categoryBlue;
  final Color categoryGoldBg;
  final Color categoryGold;
  final Color categoryTealBg;
  final Color categoryTeal;

  /// The ink shadows are tinted with.
  final Color shadow;

  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF5EAD8),
    surface: Color(0xFFEBDDC5),
    card: Color(0xFFF9F4ED),
    text: Color(0xFF201E1D),
    textMuted: Color(0xFF645C50),
    textSubtle: Color(0xFF474238),
    divider: Color(0x29201E1D),
    inverse: Color(0xFF2E2B25),
    neutral200: Color(0xFFEEE7DB),
    neutral300: Color(0xFFDCD3C4),
    neutral400: Color(0xFFC0B6A5),
    neutral500: Color(0xFFA19786),
    neutral600: Color(0xFF82796A),
    neutral700: Color(0xFF645C50),
    accent100: Color(0xFFFFF2EB),
    accent200: Color(0xFFFFE1D0),
    accent300: Color(0xFFFFC6A5),
    accent600: Color(0xFFB2622D),
    accent700: Color(0xFF8C491A),
    accent800: Color(0xFF643312),
    accent900: Color(0xFF402310),
    accent2_100: Color(0xFFF0FAE1),
    accent2_700: Color(0xFF56633F),
    accent2_900: Color(0xFF272E1B),
    categoryPlumBg: Color(0xFFF6E8EF),
    categoryPlum: Color(0xFF833A5E),
    categoryRoseBg: Color(0xFFFBE8E4),
    categoryRose: Color(0xFF9C3A2F),
    categoryBlueBg: Color(0xFFE6EEF4),
    categoryBlue: Color(0xFF2E5B80),
    categoryGoldBg: Color(0xFFFAF0DA),
    categoryGold: Color(0xFF805711),
    categoryTealBg: Color(0xFFE3F0EC),
    categoryTeal: Color(0xFF28675B),
    shadow: Color(0xFF201E1D),
  );

  /// Midnight pitch: warm near-black, the cream turned to parchment ink,
  /// and each tint flipped to a deep wash with a light ink on it.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF121210),
    surface: Color(0xFF23211E),
    card: Color(0xFF1A1917),
    text: Color(0xFFF2EBDF),
    textMuted: Color(0xFFADA597),
    textSubtle: Color(0xFFD2CABC),
    divider: Color(0x29F2EBDF),
    inverse: Color(0xFF2E2A25),
    neutral200: Color(0xFF201E1B),
    neutral300: Color(0xFF34302B),
    neutral400: Color(0xFF4A453E),
    neutral500: Color(0xFF6E675C),
    neutral600: Color(0xFF8F877A),
    neutral700: Color(0xFFADA597),
    accent100: Color(0xFF34211A),
    accent200: Color(0xFF45291B),
    accent300: Color(0xFF6B3A1E),
    accent600: Color(0xFFE08A52),
    accent700: Color(0xFFF2A26E),
    accent800: Color(0xFFFFC6A5),
    accent900: Color(0xFFFFE1D0),
    accent2_100: Color(0xFF232B1C),
    accent2_700: Color(0xFFAFC38B),
    accent2_900: Color(0xFFDDE8C8),
    categoryPlumBg: Color(0xFF35202B),
    categoryPlum: Color(0xFFE3A6C4),
    categoryRoseBg: Color(0xFF3A211D),
    categoryRose: Color(0xFFF0A598),
    categoryBlueBg: Color(0xFF1B2833),
    categoryBlue: Color(0xFF9CC3E3),
    categoryGoldBg: Color(0xFF342915),
    categoryGold: Color(0xFFE8C077),
    categoryTealBg: Color(0xFF162E29),
    categoryTeal: Color(0xFF8FD3C3),
    shadow: Color(0xFF000000),
  );
}

/// Design tokens. Most follow the active [AppPalette] — set by the app
/// root from the viewer's light / dark choice — so they're getters, not
/// constants; the brand colours that look the same either way stay const.
abstract final class AppColors {
  static AppPalette _palette = AppPalette.light;

  /// The palette screens are painted with. Changing it doesn't repaint
  /// anything by itself — the app root rebuilds the tree when it does.
  static AppPalette get palette => _palette;
  static set palette(AppPalette palette) => _palette = palette;

  static bool get isDark => _palette.brightness == Brightness.dark;

  // ── Adaptive ──────────────────────────────────────────────────────────
  static Color get bg => _palette.bg;
  static Color get surface => _palette.surface;

  /// Raised cards, sheets, inputs: cream by day, charcoal by night.
  static Color get card => _palette.card;
  static Color get text => _palette.text;
  static Color get divider => _palette.divider;

  // Text that meets WCAG AA (4.5:1) — use these, not faded [text].
  /// Captions and secondary text: 5.5:1 on [bg], 4.9:1 on [surface].
  static Color get textMuted => _palette.textMuted;

  /// Secondary text that matters (amounts' context, meta lines): 8.4:1.
  static Color get textSubtle => _palette.textSubtle;

  /// Kept for older call sites — the same as [card].
  static Color get neutral100 => _palette.card;
  static Color get neutral200 => _palette.neutral200;
  static Color get neutral300 => _palette.neutral300;
  static Color get neutral400 => _palette.neutral400;
  static Color get neutral500 => _palette.neutral500;
  static Color get neutral600 => _palette.neutral600;
  static Color get neutral700 => _palette.neutral700;

  /// The dark surfaces — hero cards, selected chips, snackbars. Dark in
  /// both themes (a lifted charcoal at night), with [onDark] text.
  static Color get neutral900 => _palette.inverse;

  static Color get accent100 => _palette.accent100;
  static Color get accent200 => _palette.accent200;
  static Color get accent300 => _palette.accent300;
  static Color get accent600 => _palette.accent600;

  /// "You owe" text and icons: a deep terra by day, a light one by night.
  /// For a filled button use [accentFill].
  static Color get accent700 => _palette.accent700;
  static Color get accent800 => _palette.accent800;
  static Color get accent900 => _palette.accent900;

  static Color get accent2_100 => _palette.accent2_100;

  /// "Is owed" / paid text and icons. For a filled button use [successFill].
  static Color get accent2_700 => _palette.accent2_700;
  static Color get accent2_900 => _palette.accent2_900;

  // Expense category tints — a wash and an ink of the same hue, the ink
  // at 4.5:1+ on its wash in both themes.
  static Color get categoryPlumBg => _palette.categoryPlumBg;
  static Color get categoryPlum => _palette.categoryPlum;
  static Color get categoryRoseBg => _palette.categoryRoseBg;
  static Color get categoryRose => _palette.categoryRose;
  static Color get categoryBlueBg => _palette.categoryBlueBg;
  static Color get categoryBlue => _palette.categoryBlue;
  static Color get categoryGoldBg => _palette.categoryGoldBg;
  static Color get categoryGold => _palette.categoryGold;
  static Color get categoryTealBg => _palette.categoryTealBg;
  static Color get categoryTeal => _palette.categoryTeal;

  // ── Fixed ─────────────────────────────────────────────────────────────
  static const accent = Color(0xFFC67139);
  static const accent2 = Color(0xFF7A8A5E);
  static const accent400 = Color(0xFFF6A06B);
  static const accent500 = Color(0xFFD67F48);

  /// Light text and icons on the dark and accent fills ([neutral900],
  /// [accent], [accentFill]) — light in both themes.
  static const onDark = Color(0xFFF9F4ED);

  /// Dark ink on a fixed light fill — a cream button on a hero card.
  static const onLight = Color(0xFF201E1D);

  /// Secondary text on the dark hero cards ([neutral900]): 6:1.
  static const onDarkMuted = Color(0xFFACA8A1);

  /// Dark text on [teamGold] fills — dark in both themes.
  static const neutral800 = Color(0xFF474238);

  /// Deep terra fill for strong buttons ("Pay", "Reject"), with [onDark].
  static const accentFill = Color(0xFF8C491A);

  /// Deep olive fill for confirming buttons, with [onDark].
  static const successFill = Color(0xFF56633F);

  /// The unread dot on a notification.
  static const unread = Color(0xFFD93A2E);

  /// Golden Goal FC's own brand colour — the team identity, not the
  /// product accent.
  static const teamGold = Color(0xFFD9A13C);
}
