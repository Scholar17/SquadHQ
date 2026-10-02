import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/app_notification.dart';
import '../models/app_notification_model.dart';

abstract interface class NotificationRemoteDataSource {
  Future<List<AppNotification>> getNotifications();

  Future<void> markRead({Set<String>? ids});

  Stream<void> watch();
}

class NotificationRemoteDataSourceImpl implements NotificationRemoteDataSource {
  NotificationRemoteDataSourceImpl({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  final SupabaseClient _supabase;

  static const _limit = 50;
  static const _retryAfter = Duration(seconds: 5);

  String get _userId {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const ServerException('You are signed out');
    return userId;
  }

  @override
  Future<List<AppNotification>> getNotifications() async {
    try {
      final rows = await _supabase
          .from('notifications')
          .select('id, kind, match_id, expense_id, team_id, title, body, created_at, read_at')
          .eq('profile_id', _userId)
          .order('created_at', ascending: false)
          .limit(_limit);
      return rows.map(AppNotificationModel.fromRow).toList();
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Future<void> markRead({Set<String>? ids}) async {
    try {
      await _supabase.rpc('mark_notifications_read', params: {'p_ids': ids?.toList()});
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    }
  }

  @override
  Stream<void> watch() {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    Timer? retry;

    void close() {
      retry?.cancel();
      final current = channel;
      channel = null;
      if (current != null) unawaited(_supabase.removeChannel(current));
    }

    void open() {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      var resubscribe = false;
      late final RealtimeChannel subscribed;
      subscribed = _supabase
          .channel('notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'profile_id',
              value: userId,
            ),
            callback: (_) => controller.add(null),
          )
          .subscribe((status, error) {
        debugPrint('[realtime] notifications: ${status.name}${error == null ? '' : ' - $error'}');
        if (channel != subscribed) return;
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            // A resubscribe may have missed changes.
            if (resubscribe) controller.add(null);
            resubscribe = true;
          case RealtimeSubscribeStatus.channelError || RealtimeSubscribeStatus.timedOut:
            // A failed subscription delivers nothing and isn't retried by
            // the client — start over.
            close();
            retry = Timer(_retryAfter, () {
              if (!controller.isClosed) open();
            });
          case RealtimeSubscribeStatus.closed:
            break;
        }
      });
      channel = subscribed;
    }

    controller = StreamController<void>(onListen: open, onCancel: close);
    return controller.stream;
  }
}
