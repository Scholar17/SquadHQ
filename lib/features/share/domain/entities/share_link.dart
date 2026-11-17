import 'package:equatable/equatable.dart';

/// What a share link opens: a match (upcoming, or its result once played)
/// or its bill. supabase/sql/054_share_links.sql.
enum ShareKind {
  match('match'),
  bill('bill');

  const ShareKind(this.dbName);

  final String dbName;

  static ShareKind? fromDb(String value) =>
      values.where((kind) => kind.dbName == value).firstOrNull;
}

/// Where share links live. Firebase Hosting redirects /s/* to the
/// Cloudflare Worker (cloudflare/share-preview), which serves the preview
/// card and sends people on to `/open/<token>` in the app.
const shareLinkBase = 'https://squad-hq.web.app/s/';

String shareUrl(String token) => '$shareLinkBase$token';

/// A share link opened by a member of its team: what to show.
class OpenedShare extends Equatable {
  const OpenedShare({
    required this.kind,
    required this.matchId,
    required this.teamId,
  });

  final ShareKind kind;
  final String matchId;
  final String teamId;

  @override
  List<Object?> get props => [kind, matchId, teamId];
}
