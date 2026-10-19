import 'package:flutter/services.dart';

import 'share_outcome.dart';

/// No share sheet without a plugin yet: copies [url] to paste anywhere.
Future<ShareOutcome> shareLink({required String url, required String title}) async {
  await Clipboard.setData(ClipboardData(text: url));
  return ShareOutcome.copied;
}
