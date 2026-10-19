import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('__hideSplash')
external JSFunction? get _hideSplash;

/// The page's splash is still up (web/index.html leaves it until told).
bool get hasWebSplash => web.document.getElementById('splash') != null;

/// Fades the page's splash into the app.
void hideWebSplash() => _hideSplash?.callAsFunction();
