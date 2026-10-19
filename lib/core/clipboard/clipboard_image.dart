// "Paste copied photo" for uploads — the browser's clipboard on the web,
// UIPasteboard on iOS (AppDelegate.swift). Not on Android yet.
export 'clipboard_image_io.dart' if (dart.library.js_interop) 'clipboard_image_web.dart';
