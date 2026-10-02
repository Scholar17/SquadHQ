import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/team_wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../models/team_wallet_model.dart';

abstract interface class WalletRemoteDataSource {
  Future<TeamWallet> getTeamWallet(String teamId);

  Future<void> setMatchBill({
    required String matchId,
    required double totalCost,
    required SplitMode splitMode,
    required Set<String> memberIds,
  });

  Future<void> submitPayment({
    required String matchId,
    required Uint8List slipBytes,
    required String fileExtension,
  });

  Future<String?> getMyWalletQr();

  Future<String> uploadWalletQr({required Uint8List bytes, required String fileExtension});

  Future<String> getImageUrl(WalletImageKind kind, String path);

  Future<Uint8List> downloadImage(WalletImageKind kind, String path);

  /// [profileIds] null = everyone still owing.
  Future<void> remindUnpaid(String matchId, {Set<String>? profileIds});
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  WalletRemoteDataSourceImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  /// How far back the wallet looks for matches without a bill; billed
  /// matches show regardless of age.
  static const _recentWindow = Duration(days: 30);

  static const _matchLimit = 60;

  static String _bucket(WalletImageKind kind) => switch (kind) {
        WalletImageKind.walletQr => 'wallet-qr',
        WalletImageKind.paymentSlip => 'payment-slips',
      };

  static String _contentType(String fileExtension) => switch (fileExtension.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };

  String get _userId {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const ServerException('You are signed out');
    return userId;
  }

  @override
  Future<TeamWallet> getTeamWallet(String teamId) async {
    try {
      final since = DateTime.now().subtract(_recentWindow).toUtc().toIso8601String();
      final (memberRows, matchRows) = await (
        _supabase.from('team_members').select('profile_id, profiles(name)').eq('team_id', teamId),
        _supabase
            .from('matches')
            .select(
              '*, payer:profiles!paid_by(name, wallet_qr_path), '
              'match_bill_members(profile_id), '
              'match_payments(profile_id, slip_path, paid_at), '
              'bill_reminders(profile_id, reminded_at)',
            )
            .eq('team_id', teamId)
            .or('total_cost.not.is.null,kickoff_at.gte.$since')
            .order('kickoff_at', ascending: false)
            .limit(_matchLimit),
      ).wait;
      final matches = (matchRows as List<dynamic>).cast<Map<String, dynamic>>();
      final matchIds = [for (final row in matches) row['id'] as String];
      final rsvpRows = matchIds.isEmpty
          ? const <dynamic>[]
          : await _supabase
              .from('match_rsvps')
              .select('match_id, profile_id, status')
              .inFilter('match_id', matchIds);
      return TeamWalletModel.fromRows(
        memberRows: (memberRows as List<dynamic>).cast<Map<String, dynamic>>(),
        matchRows: matches,
        rsvpRows: rsvpRows.cast<Map<String, dynamic>>(),
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> setMatchBill({
    required String matchId,
    required double totalCost,
    required SplitMode splitMode,
    required Set<String> memberIds,
  }) async {
    try {
      await _supabase.rpc('set_match_bill', params: {
        'p_match_id': matchId,
        'p_total_cost': totalCost,
        'p_split_mode': splitModeToDb(splitMode),
        'p_member_ids': splitMode == SplitMode.custom ? memberIds.toList() : <String>[],
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> submitPayment({
    required String matchId,
    required Uint8List slipBytes,
    required String fileExtension,
  }) async {
    try {
      // A fresh file per upload, so re-submitting never needs an
      // overwrite (storage update) policy.
      final path = '$matchId/$_userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      await _supabase.storage.from(_bucket(WalletImageKind.paymentSlip)).uploadBinary(
            path,
            slipBytes,
            fileOptions: FileOptions(contentType: _contentType(fileExtension)),
          );
      await _supabase.rpc('submit_match_payment', params: {
        'p_match_id': matchId,
        'p_slip_path': path,
      });
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<String?> getMyWalletQr() async {
    try {
      final row = await _supabase
          .from('profiles')
          .select('wallet_qr_path')
          .eq('id', _userId)
          .maybeSingle();
      return row?['wallet_qr_path'] as String?;
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<String> uploadWalletQr({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    try {
      final userId = _userId;
      final previous = await getMyWalletQr();
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final bucket = _supabase.storage.from(_bucket(WalletImageKind.walletQr));
      await bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: _contentType(fileExtension)),
      );
      await _supabase.from('profiles').update({'wallet_qr_path': path}).eq('id', userId);
      if (previous != null) {
        // Best effort — a leftover old QR image is harmless.
        try {
          await bucket.remove([previous]);
        } on StorageException {
          // Ignored.
        }
      }
      return path;
    } on StorageException catch (e) {
      throw ServerException(e.message);
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<String> getImageUrl(WalletImageKind kind, String path) async {
    try {
      return await _supabase.storage.from(_bucket(kind)).createSignedUrl(path, 60 * 60);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<Uint8List> downloadImage(WalletImageKind kind, String path) async {
    try {
      return await _supabase.storage.from(_bucket(kind)).download(path);
    } on StorageException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> remindUnpaid(String matchId, {Set<String>? profileIds}) async {
    try {
      await _supabase.rpc('remind_bill_payment', params: {
        'p_match_id': matchId,
        'p_profile_ids': profileIds?.toList(),
      });
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }
}
