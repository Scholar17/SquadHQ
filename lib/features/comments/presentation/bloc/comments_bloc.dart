import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/realtime/team_changes.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/mention.dart';

sealed class CommentsEvent extends Equatable {
  const CommentsEvent();

  @override
  List<Object?> get props => [];
}

final class CommentsStarted extends CommentsEvent {
  const CommentsStarted();
}

/// Reloads quietly — a teammate commented, replied or deleted.
final class CommentsRefreshRequested extends CommentsEvent {
  const CommentsRefreshRequested();
}

/// Posts [body] — as a reply to [parentId] if set. '@username' of a
/// member becomes a mention.
final class CommentPosted extends CommentsEvent {
  const CommentPosted(this.body, {this.parentId});

  final String body;
  final String? parentId;

  @override
  List<Object?> get props => [body, parentId];
}

final class CommentDeleted extends CommentsEvent {
  const CommentDeleted(this.commentId);

  final String commentId;

  @override
  List<Object?> get props => [commentId];
}

final class CommentsState extends Equatable {
  const CommentsState({
    this.comments = const [],
    this.members = const [],
    this.loaded = false,
    this.posting = false,
    this.postedCount = 0,
    this.error,
  });

  final List<Comment> comments;

  /// The team's members: who can be @mentioned, and how a mention shows.
  final List<MentionMember> members;
  final bool loaded;

  /// A post or delete is in flight.
  final bool posting;

  /// Bumped on each successful post — the composer clears itself on it.
  final int postedCount;

  /// The last failure, for a snackbar.
  final String? error;

  List<CommentThread> get threads => threadsOf(comments);

  CommentsState copyWith({
    List<Comment>? comments,
    List<MentionMember>? members,
    bool? loaded,
    bool? posting,
    int? postedCount,
    String? error,
  }) => CommentsState(
    comments: comments ?? this.comments,
    members: members ?? this.members,
    loaded: loaded ?? this.loaded,
    posting: posting ?? this.posting,
    postedCount: postedCount ?? this.postedCount,
    error: error,
  );

  @override
  List<Object?> get props => [comments, members, loaded, posting, postedCount, error];
}

/// Loads, posts and deletes one thread's comments — an expense's, a
/// match's or a bill's — and loads its team's members, for @mentions.
typedef CommentsSource = ({
  Future<Either<Failure, List<Comment>>> Function() load,
  Future<Either<Failure, Unit>> Function(String body, String? parentId) add,
  Future<Either<Failure, Unit>> Function(String commentId) delete,
  Future<Either<Failure, List<MentionMember>>> Function() members,
});

/// One thread, live: a factory per screen showing it, reloading whenever
/// [table] changes for the team over Realtime.
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc({
    required CommentsSource source,
    required String teamId,
    required TeamTable table,
    required TeamChanges teamChanges,
  }) : _source = source,
       super(const CommentsState()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: {table},
      onChange: () {
        if (!isClosed) add(const CommentsRefreshRequested());
      },
      // Comments are a conversation: show them quickly.
      debounce: const Duration(milliseconds: 250),
    )..watch(teamId);
    on<CommentsStarted>((event, emit) => _reload(emit));
    on<CommentsRefreshRequested>((event, emit) => _reload(emit));
    on<CommentPosted>(_onPosted);
    on<CommentDeleted>(_onDeleted);
  }

  /// The service locator names: an expense's thread, or a match's.
  static const expense = 'expense-comments';
  static const match = 'match-comments';

  final CommentsSource _source;
  late final TeamChangeWatcher _serverChanges;

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
  }

  /// The comments, and the members again — someone may have changed
  /// their username. Without members, mentions show as '@someone' and
  /// typed ones stay plain text; that's no reason to fail the thread.
  Future<void> _reload(Emitter<CommentsState> emit) async {
    final (result, members) = await (_source.load(), _source.members()).wait;
    final latestMembers = members.fold((_) => null, (members) => members);
    result.fold(
      (failure) =>
          emit(state.copyWith(members: latestMembers, loaded: true, error: failure.message)),
      (comments) => emit(state.copyWith(comments: comments, members: latestMembers, loaded: true)),
    );
  }

  Future<void> _onPosted(CommentPosted event, Emitter<CommentsState> emit) async {
    final body = event.body.trim();
    if (body.isEmpty) return;
    emit(state.copyWith(posting: true));
    final result = await _source.add(encodeMentions(body, state.members), event.parentId);
    await result.fold(
      (failure) async => emit(state.copyWith(posting: false, error: failure.message)),
      (_) async {
        emit(state.copyWith(posting: false, postedCount: state.postedCount + 1));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleted(CommentDeleted event, Emitter<CommentsState> emit) async {
    emit(state.copyWith(posting: true));
    final result = await _source.delete(event.commentId);
    await result.fold(
      (failure) async => emit(state.copyWith(posting: false, error: failure.message)),
      (_) async {
        emit(state.copyWith(posting: false));
        await _reload(emit);
      },
    );
  }
}
