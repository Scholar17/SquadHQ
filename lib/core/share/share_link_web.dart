import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'share_outcome.dart';

/// Opens the browser's share sheet for [url] (Safari, Chrome on phones),
/// or copies it where there's none (most desktop browsers).
///
/// Call it straight from a tap, before any await: browsers only open the
/// share sheet during a user's gesture.
Future<ShareOutcome> shareLink({required String url, required String title}) async {
  final navigator = web.window.navigator;
  if ((navigator as JSObject).has('share')) {
    try {
      // Just the link: Messenger and Facebook build the card from it.
      await navigator.share(web.ShareData(title: title, url: url)).toDart;
      return ShareOutcome.shared;
    } catch (e) {
      // Backed out — or the gesture had expired: copy instead.
      if (e.toString().contains('AbortError')) return ShareOutcome.cancelled;
    }
  }
  await navigator.clipboard.writeText(url).toDart;
  return ShareOutcome.copied;
}
