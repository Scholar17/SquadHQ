import 'package:equatable/equatable.dart';

/// The six card attributes, in card order.
enum StatKey {
  pac('PAC', 'Pace'),
  sho('SHO', 'Shooting'),
  pas('PAS', 'Passing'),
  dri('DRI', 'Dribbling'),
  def('DEF', 'Defending'),
  phy('PHY', 'Physical');

  const StatKey(this.short, this.label);

  final String short;
  final String label;
}

/// Which questions a main position gets — see rating_positions in
/// supabase/sql/045_player_ratings.sql.
enum PositionGroup {
  attacker('Attack'),
  midfielder('Midfield'),
  defender('Defence'),
  goalkeeper('Goal');

  const PositionGroup(this.label);

  final String label;

  static PositionGroup fromDb(String value) =>
      values.firstWhere((group) => group.name == value, orElse: () => midfielder);

  /// A position code's group, as rating_positions has it.
  static PositionGroup ofCode(String code) => switch (code) {
    'GK' => goalkeeper,
    'CB' || 'FB' => defender,
    'W' || 'ST' => attacker,
    _ => midfielder,
  };
}

/// A position a player can pick ("ST", "Striker").
class RatingPosition extends Equatable {
  const RatingPosition({required this.code, required this.name, required this.group});

  final String code;
  final String name;
  final PositionGroup group;

  @override
  List<Object?> get props => [code, name, group];
}

class RatingAnswer extends Equatable {
  const RatingAnswer({required this.id, required this.body});

  final String id;
  final String body;

  @override
  List<Object?> get props => [id, body];
}

/// One multiple-choice question. Which answers move which stats stays on
/// the server.
class RatingQuestion extends Equatable {
  const RatingQuestion({required this.id, required this.body, required this.answers});

  final String id;
  final String body;
  final List<RatingAnswer> answers;

  @override
  List<Object?> get props => [id, body, answers];
}

/// A player's card: their positions (main first), six stats and OVR.
class PlayerRating extends Equatable {
  const PlayerRating({
    required this.positions,
    required this.stats,
    required this.ovr,
    required this.ratedAt,
    this.improvements = 0,
  });

  final List<String> positions;
  final Map<StatKey, int> stats;
  final int ovr;
  final DateTime ratedAt;

  /// How many 10-match boosts have landed.
  final int improvements;

  String get mainPosition => positions.first;

  PositionGroup get group => PositionGroup.ofCode(mainPosition);

  int stat(StatKey key) => stats[key] ?? 0;

  @override
  List<Object?> get props => [positions, stats, ovr, ratedAt, improvements];
}

/// One teammate on the Squad tab.
class RatedPlayer extends Equatable {
  const RatedPlayer({
    required this.profileId,
    required this.name,
    this.avatarUrl,
    this.rating,
    this.apps = 0,
    this.goals = 0,
    this.assists = 0,
    this.saves = 0,
    this.tackles = 0,
    this.cleanSheets = 0,
    this.progress = 0,
  });

  /// Matches between boosts.
  static const boostEvery = 10;

  final String profileId;
  final String name;
  final String? avatarUrl;

  /// Null until they've filled it in.
  final PlayerRating? rating;

  /// Finished matches they played (still on record — a year back).
  final int apps;
  final int goals;
  final int assists;
  final int saves;

  /// Tackles & interceptions they've logged.
  final int tackles;

  /// Matches they played with nothing conceded — from the recorded score.
  final int cleanSheets;

  /// Matches played towards the next boost, 0–[boostEvery].
  final int progress;

  bool get isRated => rating != null;
  bool get canImprove => isRated && progress >= boostEvery;

  @override
  List<Object?> get props => [
    profileId,
    name,
    avatarUrl,
    rating,
    apps,
    goals,
    assists,
    saves,
    tackles,
    cleanSheets,
    progress,
  ];
}

/// What a player logged for one match, plus what the server knows about
/// it for them.
class MatchStats extends Equatable {
  const MatchStats({
    this.goals = 0,
    this.assists = 0,
    this.saves = 0,
    this.tackles = 0,
    this.logged = false,
    this.cleanSheet,
    this.group,
  });

  final int goals;
  final int assists;
  final int saves;

  /// Tackles & interceptions.
  final int tackles;

  /// Whether they've saved anything for this match yet.
  final bool logged;

  /// Nothing conceded — null until the score's recorded.
  final bool? cleanSheet;

  /// Their main position's group — decides which stats to ask for. Null
  /// before they've rated.
  final PositionGroup? group;

  int of(LoggedStat stat) => switch (stat) {
    LoggedStat.goals => goals,
    LoggedStat.assists => assists,
    LoggedStat.tackles => tackles,
    LoggedStat.saves => saves,
  };

  /// [stat] moved by [delta], kept in its range.
  MatchStats step(LoggedStat stat, int delta) {
    final value = (of(stat) + delta).clamp(0, stat.max);
    return copyWith(
      goals: stat == LoggedStat.goals ? value : null,
      assists: stat == LoggedStat.assists ? value : null,
      tackles: stat == LoggedStat.tackles ? value : null,
      saves: stat == LoggedStat.saves ? value : null,
    );
  }

  MatchStats copyWith({int? goals, int? assists, int? saves, int? tackles, bool? logged}) =>
      MatchStats(
        goals: goals ?? this.goals,
        assists: assists ?? this.assists,
        saves: saves ?? this.saves,
        tackles: tackles ?? this.tackles,
        logged: logged ?? this.logged,
        cleanSheet: cleanSheet,
        group: group,
      );

  @override
  List<Object?> get props => [goals, assists, saves, tackles, logged, cleanSheet, group];
}

/// The per-match stats worth logging for a position group, most useful
/// first — a keeper isn't asked about tackles, a striker not about saves.
/// Not rated yet: all four.
enum LoggedStat {
  goals('Goals', 30),
  assists('Assists', 30),
  tackles('Tackles & interceptions', 60),
  saves('Saves', 60);

  const LoggedStat(this.label, this.max);

  final String label;

  /// As log_match_stats allows.
  final int max;

  static List<LoggedStat> forGroup(PositionGroup? group) => switch (group) {
    PositionGroup.attacker => const [goals, assists],
    PositionGroup.midfielder => const [assists, goals, tackles],
    PositionGroup.defender => const [tackles, goals, assists],
    PositionGroup.goalkeeper => const [saves, assists],
    null => const [goals, assists, tackles, saves],
  };
}

/// The Squad tab's numbers: the average OVR of whoever's rated.
extension SquadAverage on List<RatedPlayer> {
  int? get averageOvr {
    final rated = [for (final player in this) ?player.rating?.ovr];
    if (rated.isEmpty) return null;
    return (rated.reduce((a, b) => a + b) / rated.length).round();
  }

  int get ratedCount => where((player) => player.isRated).length;
}
