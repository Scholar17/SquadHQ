// Browser facts web push depends on — false everywhere but the web.
export 'web_platform_stub.dart' if (dart.library.js_interop) 'web_platform_web.dart';
