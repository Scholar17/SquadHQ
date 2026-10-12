/// Which of a football match's two threads a comment is in: the match
/// itself (Match tab) or its bill (Wallet tab). See
/// supabase/sql/043_match_comments.sql.
enum MatchTopic {
  match('match'),
  bill('bill');

  const MatchTopic(this.dbName);

  final String dbName;
}

/// One match thread: [matchId]'s comments on [topic].
typedef MatchThread = ({String matchId, MatchTopic topic});
