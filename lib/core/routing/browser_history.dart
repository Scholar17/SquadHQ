// Moving through the browser's history — for WebBackGuard; a no-op off the
// web (package:web can't be imported on Android/iOS builds).
export 'browser_history_stub.dart' if (dart.library.js_interop) 'browser_history_web.dart';
