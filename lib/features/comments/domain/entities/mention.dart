import 'package:equatable/equatable.dart';

/// A teammate who can be @mentioned in a comment.
class MentionMember extends Equatable {
  const MentionMember({required this.id, required this.name, this.username, this.photoUrl});

  final String id;
  final String name;
  final String? username;
  final String? photoUrl;

  /// What follows the @: their username, or their name for a profile
  /// without one.
  String get handle => username ?? name;

  @override
  List<Object?> get props => [id, name, username, photoUrl];
}

/// A comment body is saved with each mention as '<@profile id>'
/// (supabase/sql/049_mentions.sql), never the name typed — so renaming
/// yourself updates every old mention. The composer shows plain
/// '@username' text; [encodeMentions] swaps it for markers on send and
/// [mentionParts] turns markers back into the current @username to show.
final _marker = RegExp(r'<@([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})>');

/// '@name' typed in the composer: not straight after a letter or digit (so
/// not an email address).
final _typed = RegExp(r'(?<![A-Za-z0-9_])@([A-Za-z][A-Za-z0-9_]*)');

/// [text] with each '@username' of one of [members] (any case) as its
/// marker. Anything else after an @ stays as typed.
String encodeMentions(String text, List<MentionMember> members) {
  final byUsername = {
    for (final member in members)
      if (member.username case final username?) username.toLowerCase(): member,
  };
  return text.replaceAllMapped(_typed, (match) {
    final member = byUsername[match[1]!.toLowerCase()];
    return member == null ? match[0]! : '<@${member.id}>';
  });
}

/// A run of a comment's text: plain, or a mention of [memberId].
typedef MentionPart = ({String text, String? memberId});

/// [body] split into plain text and mentions, each mention as '@' and the
/// member's current handle ('@someone' for a person no longer in
/// [members]).
List<MentionPart> mentionParts(String body, List<MentionMember> members) {
  final byId = {for (final member in members) member.id: member};
  final parts = <MentionPart>[];
  var start = 0;
  for (final match in _marker.allMatches(body)) {
    if (match.start > start) {
      parts.add((text: body.substring(start, match.start), memberId: null));
    }
    final id = match[1]!;
    parts.add((text: '@${byId[id]?.handle ?? 'someone'}', memberId: id));
    start = match.end;
  }
  if (start < body.length) parts.add((text: body.substring(start), memberId: null));
  return parts;
}

/// [body] as plain text, mentions shown as @username — for one-line
/// previews.
String plainMentions(String body, List<MentionMember> members) =>
    mentionParts(body, members).map((part) => part.text).join();

/// The '@partial' being typed just before the cursor in [text], for the
/// suggestion list: its start index and what's typed after the @ so far.
({int start, String query})? mentionQueryAt(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final match = RegExp(r'(?<![A-Za-z0-9_])@([A-Za-z0-9_]*)$').firstMatch(text.substring(0, cursor));
  if (match == null) return null;
  return (start: match.start, query: match[1]!);
}

/// [members] whose username or name starts with [query] (any case) —
/// usernames first. Leaves out [me].
List<MentionMember> mentionSuggestions(
  List<MentionMember> members,
  String query, {
  required String me,
}) {
  final q = query.toLowerCase();
  bool usernameMatches(MentionMember m) => m.username?.toLowerCase().startsWith(q) ?? false;
  bool nameMatches(MentionMember m) =>
      m.name.toLowerCase().split(RegExp(r'\s+')).any((word) => word.startsWith(q));
  final others = members.where((m) => m.id != me && m.username != null);
  return [
    ...others.where(usernameMatches),
    ...others.where((m) => !usernameMatches(m) && nameMatches(m)),
  ];
}
