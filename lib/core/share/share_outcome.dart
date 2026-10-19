/// How a share ended.
enum ShareOutcome {
  /// Handed to the share sheet.
  shared,

  /// Put on the clipboard — no share sheet here.
  copied,

  /// Backed out of the share sheet.
  cancelled,
}
