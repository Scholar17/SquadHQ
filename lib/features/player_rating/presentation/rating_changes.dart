import 'package:flutter/foundation.dart';

/// Ticks whenever the signed-in player's rating changes (rated, levelled
/// up) — so the Squad tab reloads even when the change came from the
/// forced gate, which can't reach the tab's bloc.
class RatingChanges extends ChangeNotifier {
  void bump() => notifyListeners();
}

final ratingChanges = RatingChanges();
