import 'package:web/web.dart' as web;

/// `history.go(delta)`: moves [delta] entries through the browser's history
/// (negative is back), arriving as a single popstate.
void browserHistoryGo(int delta) => web.window.history.go(delta);
