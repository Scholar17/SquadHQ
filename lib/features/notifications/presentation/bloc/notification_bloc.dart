import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/usecases/get_notifications.dart';
import '../../domain/usecases/mark_notifications_read.dart';
import '../../domain/usecases/watch_notifications.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the list and starts listening for new ones — when the signed-in
/// shell appears, and again each time the app returns to the foreground.
final class NotificationsStarted extends NotificationEvent {
  const NotificationsStarted();
}

/// Stops listening — the app went to the background, or ([clear]) the
/// player signed out, so the next one never sees their list.
final class NotificationsStopped extends NotificationEvent {
  const NotificationsStopped({this.clear = false});

  final bool clear;

  @override
  List<Object?> get props => [clear];
}

/// Reloads quietly — a change arrived over Realtime, or pull-to-refresh.
final class NotificationsRefreshRequested extends NotificationEvent {
  const NotificationsRefreshRequested({this.done});

  /// Completed once the reload finishes — for pull-to-refresh.
  final Completer<void>? done;

  @override
  List<Object?> get props => [done];
}

/// The player opened one notification.
final class NotificationOpened extends NotificationEvent {
  const NotificationOpened(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// "Read all".
final class NotificationsAllRead extends NotificationEvent {
  const NotificationsAllRead();
}

final class NotificationState extends Equatable {
  const NotificationState({this.items = const [], this.loaded = false, this.error});

  /// Newest first.
  final List<AppNotification> items;

  /// False until the first load finishes.
  final bool loaded;

  /// The last load or mark-read failure, for a snackbar.
  final String? error;

  int get unreadCount => items.where((item) => !item.isRead).length;

  @override
  List<Object?> get props => [items, loaded, error];
}

/// Singleton, provided at the app root (see app.dart): Home's bell count
/// and the notification list share it.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc({
    required GetNotifications getNotifications,
    required MarkNotificationsRead markNotificationsRead,
    required WatchNotifications watchNotifications,
  })  : _getNotifications = getNotifications,
        _markNotificationsRead = markNotificationsRead,
        _watchNotifications = watchNotifications,
        super(const NotificationState()) {
    on<NotificationsStarted>(_onStarted);
    on<NotificationsStopped>((event, emit) {
      _stopWatching();
      if (event.clear) emit(const NotificationState());
    });
    on<NotificationsRefreshRequested>(_onRefreshRequested);
    on<NotificationOpened>(_onOpened);
    on<NotificationsAllRead>(_onAllRead);
  }

  final GetNotifications _getNotifications;
  final MarkNotificationsRead _markNotificationsRead;
  final WatchNotifications _watchNotifications;

  /// Coalesces a burst (one dispatcher run can file several at once).
  static const _changeDebounce = Duration(milliseconds: 500);

  StreamSubscription<void>? _changes;
  Timer? _changeTimer;

  void _stopWatching() {
    _changeTimer?.cancel();
    unawaited(_changes?.cancel());
    _changes = null;
  }

  @override
  Future<void> close() async {
    _stopWatching();
    return super.close();
  }

  Future<void> _reload(Emitter<NotificationState> emit) async {
    final result = await _getNotifications(const NoParams());
    result.fold(
      (failure) => emit(
        NotificationState(items: state.items, loaded: true, error: failure.message),
      ),
      (items) => emit(NotificationState(items: items, loaded: true)),
    );
  }

  Future<void> _onStarted(NotificationsStarted event, Emitter<NotificationState> emit) async {
    _stopWatching();
    _changes = _watchNotifications().listen((_) {
      _changeTimer?.cancel();
      _changeTimer = Timer(_changeDebounce, () {
        if (!isClosed) add(const NotificationsRefreshRequested());
      });
    });
    await _reload(emit);
  }

  Future<void> _onRefreshRequested(
    NotificationsRefreshRequested event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _reload(emit);
    } finally {
      event.done?.complete();
    }
  }

  /// Marks [ids] (null = all) read right away, then on the server; puts
  /// them back if that fails.
  Future<void> _markRead(Set<String>? ids, Emitter<NotificationState> emit) async {
    final before = state.items;
    final now = DateTime.now();
    final after = [
      for (final item in before)
        if (!item.isRead && (ids == null || ids.contains(item.id))) item.markedRead(now) else item,
    ];
    if (after.every((item) => before.contains(item))) return;
    emit(NotificationState(items: after, loaded: state.loaded));
    final result = await _markNotificationsRead(ids);
    result.fold(
      (failure) => emit(NotificationState(items: before, loaded: state.loaded, error: failure.message)),
      (_) {},
    );
  }

  Future<void> _onOpened(NotificationOpened event, Emitter<NotificationState> emit) =>
      _markRead({event.id}, emit);

  Future<void> _onAllRead(NotificationsAllRead event, Emitter<NotificationState> emit) =>
      _markRead(null, emit);
}
