import 'package:equatable/equatable.dart';

/// One short game inside a match ("Game 2: 3–1") — see match_games in
/// supabase/sql/053_match_questions.sql. Both scores null = "Not sure".
class MatchGame extends Equatable {
  const MatchGame({
    required this.gameNo,
    this.ourScore,
    this.theirScore,
    this.updatedBy,
    this.updatedAt,
  });

  final int gameNo;
  final int? ourScore;
  final int? theirScore;

  /// Who changed it last (null once they've left).
  final String? updatedBy;
  final DateTime? updatedAt;

  bool get isNotSure => ourScore == null || theirScore == null;

  /// "3–1", or "?" for Not sure.
  String get scoreLabel => isNotSure ? '?' : '$ourScore–$theirScore';

  @override
  List<Object?> get props => [gameNo, ourScore, theirScore, updatedBy, updatedAt];
}

/// "+2 more" style score line for a match's games: up to [shown] scores,
/// then a count of the rest — "3–1 · 0–0 · +2 more". Empty with no games.
String gamesSummary(List<MatchGame> games, {int shown = 2}) {
  if (games.isEmpty) return '';
  final parts = [for (final game in games.take(shown)) game.scoreLabel];
  if (games.length > shown) parts.add('+${games.length - shown} more');
  return parts.join(' · ');
}

/// Where a player played most in one match — the setup question.
enum PlayedPosition {
  attacker('Attack'),
  midfielder('Middle'),
  defender('Defence'),
  goalkeeper('Goal');

  const PlayedPosition(this.label);

  final String label;

  static PlayedPosition? fromDb(String? value) {
    for (final position in values) {
      if (position.name == value) return position;
    }
    return null;
  }
}

/// One after-match question: its words and choices, in order. Which stat
/// it feeds is decided on the server (match_question_stats).
class MatchQuestion {
  const MatchQuestion(this.text, this.choices);

  final String text;
  final List<String> choices;
}

const _counts4 = ['0', '1', '2–3', '4 or more'];
const _often3 = ['Not much', 'Sometimes', 'A lot'];

/// The 3 questions per position, then question 4's teammate pick. The same
/// every match. Keep in step with match_question_stats in 053.
const matchQuestions = <PlayedPosition, List<MatchQuestion>>{
  PlayedPosition.attacker: [
    MatchQuestion('How many goals did you score?', _counts4),
    MatchQuestion('How many goals did you help make?', _counts4),
    MatchQuestion('How often did you get past a player?', _often3),
  ],
  PlayedPosition.midfielder: [
    MatchQuestion('How many goals did you help make?', _counts4),
    MatchQuestion('How many goals did you score?', _counts4),
    MatchQuestion('How often did you take the ball back?', _often3),
  ],
  PlayedPosition.defender: [
    MatchQuestion('How often did you stop their attack?', _often3),
    MatchQuestion('How often did you pass well to start an attack?', _often3),
    MatchQuestion('How many goals did you score or help make?', ['0', '1', '2 or more']),
  ],
  PlayedPosition.goalkeeper: [
    MatchQuestion('How many saves did you make?', ['0–2', '3–5', '6–9', '10 or more']),
    MatchQuestion(
      'How often did your throws and kicks reach a teammate?',
      ['Not much', 'About half', 'Most times'],
    ),
    MatchQuestion('How often did you come out to stop an attack?', _often3),
  ],
};

/// Question 4, per position: pick a teammate.
const matchPickQuestions = <PlayedPosition, String>{
  PlayedPosition.attacker: 'Who was the best attacker today?',
  PlayedPosition.midfielder: 'Who controlled the game best today?',
  PlayedPosition.defender: 'Who was the best defender today?',
  PlayedPosition.goalkeeper: 'Who helped you most in defence today?',
};

/// A player's answers for one match. Null answers and [pickId] = "Not sure".
class MatchAnswers extends Equatable {
  const MatchAnswers({required this.position, this.answers = const [null, null, null], this.pickId});

  final PlayedPosition position;

  /// Questions 1–3: the picked choice's index, or null.
  final List<int?> answers;
  final String? pickId;

  @override
  List<Object?> get props => [position, answers, pickId];
}
