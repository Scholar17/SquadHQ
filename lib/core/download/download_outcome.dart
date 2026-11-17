/// How a web save went.
enum DownloadOutcome {
  /// Downloaded as a file.
  downloaded,

  /// Handed to the iPhone/iPad share sheet (Save Image → Photos).
  shared,

  /// The person closed the share sheet.
  cancelled,

  /// The browser wants a fresh tap before it opens the share sheet.
  needsTap,
}
