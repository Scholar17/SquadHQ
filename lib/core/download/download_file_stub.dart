import 'dart:typed_data';

import 'download_outcome.dart';

export 'download_outcome.dart';

/// Only the web downloads files; the app saves images with `gal`.
Future<DownloadOutcome> downloadFile(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) =>
    throw UnsupportedError('downloadFile is web-only');
