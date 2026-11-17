import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'download_outcome.dart';

export 'download_outcome.dart';

/// Saves [bytes] as [fileName]. On an iPhone or iPad, opens the share
/// sheet so "Save Image" puts it straight into Photos — a plain download
/// there opens the image in a preview page first (and lands in Files, not
/// Photos). Elsewhere it downloads straight to Downloads.
Future<DownloadOutcome> downloadFile(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  if (_isAppleMobile()) {
    final file = web.File([bytes.toJS].toJS, fileName, web.FilePropertyBag(type: mimeType));
    final data = web.ShareData(files: [file].toJS);
    final navigator = web.window.navigator;
    if (navigator.canShare(data)) {
      try {
        await navigator.share(data).toDart;
        return DownloadOutcome.shared;
      } catch (e) {
        final error = (e as JSAny?);
        final name = error.isA<web.DOMException>() ? (error as web.DOMException).name : '';
        if (name == 'AbortError') return DownloadOutcome.cancelled;
        // Safari only shares during a tap; fetching the image first can
        // use that up, so the caller asks for one more tap.
        if (name == 'NotAllowedError') return DownloadOutcome.needsTap;
        // Anything else: fall back to a plain download.
      }
    }
  }
  _anchorDownload(bytes, fileName: fileName, mimeType: mimeType);
  return DownloadOutcome.downloaded;
}

/// iPhone, iPod or iPad — iPadOS reports itself as a Mac, so a touch
/// screen gives it away.
bool _isAppleMobile() {
  final navigator = web.window.navigator;
  final ua = navigator.userAgent;
  if (RegExp('iPhone|iPad|iPod').hasMatch(ua)) return true;
  return ua.contains('Macintosh') && navigator.maxTouchPoints > 1;
}

void _anchorDownload(Uint8List bytes, {required String fileName, required String mimeType}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Give the browser a moment to start the download before freeing it.
  Future<void>.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}
