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
    this.lastBoost = const [],
    this.droppedAt,
  });

  final List<String> positions;
  final Map<StatKey, int> stats;
  final int ovr;
  final DateTime ratedAt;

  /// How many 10-match boosts have landed.
  final int improvements;

  /// What the last boost gave; empty before the first (or for one from
  /// before 053).
  final List<BoostPart> lastBoost;

  /// When the rating last dropped for not playing (PHY −2, PAC −1).
  final DateTime? droppedAt;

  String get mainPosition => positions.first;

  PositionGroup get group => PositionGroup.ofCode(mainPosition);

  int stat(StatKey key) => stats[key] ?? 0;

  @override
  List<Object?> get props => [positions, stats, ovr, ratedAt, improvements, lastBoost, droppedAt];
}

/// One teammate on the Squad tab.
class RatedPlayer extends Equatable {
  const RatedPlayer({
    required this.profileId,
    required this.name,
    this.username,
    this.avatarUrl,
    this.rating,
    this.apps = 0,
    this.goals = 0,
    this.assists = 0,
    this.saves = 0,
    this.tackles = 0,
    this.cleanSheets = 0,
    this.motmWins = 0,
    this.gamesWon = 0,
    this.progress = 0,
  });

  /// Matches between boosts.
  static const boostEvery = 10;

  final String profileId;
  final String name;

  /// Their @mention name; null if not set (or not loaded).
  final String? username;
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

  /// Games they played with nothing conceded (old matches: the score an
  /// admin recorded).
  final int cleanSheets;

  /// Man of the Match wins.
  final int motmWins;

  /// Games won in the matches they played.
  final int gamesWon;

  /// Matches played towards the next boost, 0–[boostEvery].
  final int progress;

  bool get isRated => rating != null;
  bool get canImprove => isRated && progress >= boostEvery;

  @override
  List<Object?> get props => [
    profileId,
    name,
    username,
    avatarUrl,
    rating,
    apps,
    goals,
    assists,
    saves,
    tackles,
    cleanSheets,
    motmWins,
    gamesWon,
    progress,
  ];
}

/// Where a level-up's points came from (053's improve_player_rating).
enum BoostSource {
  answers('questions'),
  picks('teammates'),
  wins('wins'),
  cleanSheets('clean sheets'),
  showingUp('showing up'),
  motm('MOTM'),
  other('other');

  const BoostSource(this.label);

  final String label;

  static BoostSource fromDb(String? value) => switch (value) {
    'answers' => answers,
    'picks' => picks,
    'wins' => wins,
    'clean_sheets' => cleanSheets,
    'showing_up' => showingUp,
    'motm' => motm,
    _ => other,
  };
}

/// One line of a level-up's breakdown: "+3 SHO from MOTM".
class BoostPart extends Equatable {
  const BoostPart({required this.stat, required this.points, required this.source});

  final StatKey stat;
  final int points;
  final BoostSource source;

  @override
  String toString() => '+$points ${stat.short} from ${source.label}';

  @override
  List<Object?> get props => [stat, points, source];
}

/// "+3 SHO from MOTM · +2 SHO from teammates · +1 PHY from wins" —
/// biggest first.
String boostSummary(List<BoostPart> parts) =>
    ([...parts]..sort((a, b) => b.points.compareTo(a.points))).join(' · ');

/// The Squad tab's numbers: the average OVR of whoever's rated.
extension SquadAverage on List<RatedPlayer> {
  int? get averageOvr {
    final rated = [for (final player in this) ?player.rating?.ovr];
    if (rated.isEmpty) return null;
    return (rated.reduce((a, b) => a + b) / rated.length).round();
  }

  int get ratedCount => where((player) => player.isRated).length;
}
