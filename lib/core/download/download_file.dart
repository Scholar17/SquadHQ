// Saving bytes as a file download — the web only; phones save to Photos
// with `gal` instead.
export 'download_file_stub.dart' if (dart.library.js_interop) 'download_file_web.dart';
