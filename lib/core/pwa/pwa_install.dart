// Profile's "Install app" — a no-op everywhere but the web (pwa_installer
// reaches for browser APIs, so it can't be imported on Android/iOS builds).
export 'pwa_install_stub.dart' if (dart.library.js_interop) 'pwa_install_web.dart';
