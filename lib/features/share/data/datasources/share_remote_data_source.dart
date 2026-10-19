import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/share_link.dart';

abstract interface class ShareRemoteDataSource {
  Future<String> getShareLink(String matchId, ShareKind kind);

  Future<void> recordShare(String matchId, ShareKind kind);

  Future<OpenedShare?> openShareLink(String token);
}

/// 054's share_link and open_share_link, and 055's record_share.
class ShareRemoteDataSourceImpl implements ShareRemoteDataSource {
  ShareRemoteDataSourceImpl({required SupabaseClient supabaseClient})
    : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  @override
  Future<String> getShareLink(String matchId, ShareKind kind) async {
    try {
      final token = await _supabase.rpc(
        'share_link',
        params: {'p_match_id': matchId, 'p_kind': kind.dbName},
      );
      return shareUrl(token as String);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> recordShare(String matchId, ShareKind kind) async {
    try {
      await _supabase.rpc(
        'record_share',
        params: {'p_match_id': matchId, 'p_kind': kind.dbName},
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<OpenedShare?> openShareLink(String token) async {
    try {
      final rows = await _supabase.rpc('open_share_link', params: {'p_token': token}) as List;
      if (rows.isEmpty) return null;
      final row = rows.first as Map<String, dynamic>;
      final kind = ShareKind.fromDb(row['kind'] as String);
      if (kind == null) return null;
      return OpenedShare(
        kind: kind,
        matchId: row['match_id'] as String,
        teamId: row['team_id'] as String,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
