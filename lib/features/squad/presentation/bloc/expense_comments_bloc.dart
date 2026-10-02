import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/realtime/team_changes.dart';
import '../../domain/entities/expense_comment.dart';
import '../../domain/usecases/squad_usecases.dart';

sealed class ExpenseCommentsEvent extends Equatable {
  const ExpenseCommentsEvent();

  @override
  List<Object?> get props => [];
}

final class ExpenseCommentsStarted extends ExpenseCommentsEvent {
  const ExpenseCommentsStarted();
}

/// Reloads quietly — a squad-mate commented, replied or deleted.
final class ExpenseCommentsRefreshRequested extends ExpenseCommentsEvent {
  const ExpenseCommentsRefreshRequested();
}

/// Posts [body] — as a reply to [parentId] if set.
final class ExpenseCommentPosted extends ExpenseCommentsEvent {
  const ExpenseCommentPosted(this.body, {this.parentId});

  final String body;
  final String? parentId;

  @override
  List<Object?> get props => [body, parentId];
}

final class ExpenseCommentDeleted extends ExpenseCommentsEvent {
  const ExpenseCommentDeleted(this.commentId);

  final String commentId;

  @override
  List<Object?> get props => [commentId];
}

final class ExpenseCommentsState extends Equatable {
  const ExpenseCommentsState({
    this.comments = const [],
    this.loaded = false,
    this.posting = false,
    this.postedCount = 0,
    this.error,
  });

  final List<ExpenseComment> comments;
  final bool loaded;

  /// A post or delete is in flight.
  final bool posting;

  /// Bumped on each successful post — the composer clears itself on it.
  final int postedCount;

  /// The last failure, for a snackbar.
  final String? error;

  List<CommentThread> get threads => threadsOf(comments);

  ExpenseCommentsState copyWith({
    List<ExpenseComment>? comments,
    bool? loaded,
    bool? posting,
    int? postedCount,
    String? error,
  }) => ExpenseCommentsState(
    comments: comments ?? this.comments,
    loaded: loaded ?? this.loaded,
    posting: posting ?? this.posting,
    postedCount: postedCount ?? this.postedCount,
    error: error,
  );

  @override
  List<Object?> get props => [comments, loaded, posting, postedCount, error];
}

/// One expense's comment thread, live: a factory per expense detail screen,
/// reloading whenever the squad's comments change over Realtime.
class ExpenseCommentsBloc extends Bloc<ExpenseCommentsEvent, ExpenseCommentsState> {
  ExpenseCommentsBloc({
    required this.expenseId,
    required String teamId,
    required GetExpenseComments getComments,
    required AddExpenseComment addComment,
    required DeleteExpenseComment deleteComment,
    required TeamChanges teamChanges,
  }) : _getComments = getComments,
       _addComment = addComment,
       _deleteComment = deleteComment,
       super(const ExpenseCommentsState()) {
    _serverChanges = TeamChangeWatcher(
      teamChanges,
      tables: const {TeamTable.expenseComments},
      onChange: () {
        if (!isClosed) add(const ExpenseCommentsRefreshRequested());
      },
      // Comments are a conversation: show them quickly.
      debounce: const Duration(milliseconds: 250),
    )..watch(teamId);
    on<ExpenseCommentsStarted>((event, emit) => _reload(emit));
    on<ExpenseCommentsRefreshRequested>((event, emit) => _reload(emit));
    on<ExpenseCommentPosted>(_onPosted);
    on<ExpenseCommentDeleted>(_onDeleted);
  }

  final String expenseId;
  final GetExpenseComments _getComments;
  final AddExpenseComment _addComment;
  final DeleteExpenseComment _deleteComment;
  late final TeamChangeWatcher _serverChanges;

  @override
  Future<void> close() async {
    await _serverChanges.cancel();
    return super.close();
  }

  Future<void> _reload(Emitter<ExpenseCommentsState> emit) async {
    final result = await _getComments(expenseId);
    result.fold(
      (failure) => emit(state.copyWith(loaded: true, error: failure.message)),
      (comments) => emit(state.copyWith(comments: comments, loaded: true)),
    );
  }

  Future<void> _onPosted(ExpenseCommentPosted event, Emitter<ExpenseCommentsState> emit) async {
    final body = event.body.trim();
    if (body.isEmpty) return;
    emit(state.copyWith(posting: true));
    final result = await _addComment((expenseId: expenseId, body: body, parentId: event.parentId));
    await result.fold(
      (failure) async => emit(state.copyWith(posting: false, error: failure.message)),
      (_) async {
        emit(state.copyWith(posting: false, postedCount: state.postedCount + 1));
        await _reload(emit);
      },
    );
  }

  Future<void> _onDeleted(ExpenseCommentDeleted event, Emitter<ExpenseCommentsState> emit) async {
    emit(state.copyWith(posting: true));
    final result = await _deleteComment(event.commentId);
    await result.fold(
      (failure) async => emit(state.copyWith(posting: false, error: failure.message)),
      (_) async {
        emit(state.copyWith(posting: false));
        await _reload(emit);
      },
    );
  }
}
