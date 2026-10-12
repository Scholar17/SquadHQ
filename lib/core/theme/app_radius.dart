import 'package:flutter/painting.dart';

/// Corner radii: one scale for the whole app.
abstract final class AppRadius {
  /// Small bits: thumbnails, tags.
  static const xs = BorderRadius.all(Radius.circular(8));

  /// Inputs, small tiles, list rows.
  static const sm = BorderRadius.all(Radius.circular(12));

  /// Cards and panels.
  static const md = BorderRadius.all(Radius.circular(16));

  /// Feature cards (bill, hero, settle cards).
  static const lg = BorderRadius.all(Radius.circular(20));

  /// Big surfaces and dialogs.
  static const xl = BorderRadius.all(Radius.circular(24));

  /// Fully rounded: pills, chips, progress bars.
  static const pill = BorderRadius.all(Radius.circular(999));

  /// The top corners of a bottom sheet.
  static const sheet = BorderRadius.vertical(top: Radius.circular(24));
}
