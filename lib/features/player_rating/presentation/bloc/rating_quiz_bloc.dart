import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/player_rating.dart';
import '../../domain/usecases/player_rating_usecases.dart';

sealed class RatingQuizEvent extends Equatable {
  const RatingQuizEvent();

  @override
  List<Object?> get props => [];
}

final class RatingQuizStarted extends RatingQuizEvent {
  const RatingQuizStarted();
}

/// Adds [code] to the picked positions (the first picked is the main
/// one), or takes it off.
final class RatingPositionToggled extends RatingQuizEvent {
  const RatingPositionToggled(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// Positions done — fetch this player's questions for the main one.
final class RatingPositionsConfirmed extends RatingQuizEvent {
  const RatingPositionsConfirmed();
}

final class RatingAnswerPicked extends RatingQuizEvent {
  const RatingAnswerPicked({required this.questionId, required this.answerId});

  final String questionId;
  final String answerId;

  @override
  List<Object?> get props => [questionId, answerId];
}

/// Back from the questions to change positions.
final class RatingBackToPositions extends RatingQuizEvent {
  const RatingBackToPositions();
}

final class RatingQuizSubmitted extends RatingQuizEvent {
  const RatingQuizSubmitted();
}

enum RatingQuizStep { positions, questions, result }

final class RatingQuizState extends Equatable {
  const RatingQuizState({
    this.step = RatingQuizStep.positions,
    this.positions = const [],
    this.picked = const [],
    this.questions = const [],
    this.answers = const {},
    this.loading = false,
    this.result,
    this.error,
  });

  static const maxPositions = 3;

  final RatingQuizStep step;
  final List<RatingPosition> positions;

  /// Position codes in the order picked — main first.
  final List<String> picked;
  final List<RatingQuestion> questions;

  /// Question id → answer id.
  final Map<String, String> answers;
  final bool loading;
  final PlayerRating? result;
  final String? error;

  bool get allAnswered =>
      questions.isNotEmpty && questions.every((question) => answers.containsKey(question.id));

  RatingQuizState copyWith({
    RatingQuizStep? step,
    List<RatingPosition>? positions,
    List<String>? picked,
    List<RatingQuestion>? questions,
    Map<String, String>? answers,
    bool? loading,
    PlayerRating? result,
    String? error,
  }) => RatingQuizState(
    step: step ?? this.step,
    positions: positions ?? this.positions,
    picked: picked ?? this.picked,
    questions: questions ?? this.questions,
    answers: answers ?? this.answers,
    loading: loading ?? this.loading,
    result: result ?? this.result,
    error: error,
  );

  @override
  List<Object?> get props => [step, positions, picked, questions, answers, loading, result, error];
}

/// Fill rating: pick positions → answer this player's questions → reveal.
class RatingQuizBloc extends Bloc<RatingQuizEvent, RatingQuizState> {
  RatingQuizBloc({
    required GetRatingPositions getPositions,
    required GetRatingQuestions getQuestions,
    required SubmitRating submitRating,
  }) : _getPositions = getPositions,
       _getQuestions = getQuestions,
       _submitRating = submitRating,
       super(const RatingQuizState(loading: true)) {
    on<RatingQuizStarted>(_onStarted);
    on<RatingPositionToggled>(_onToggled);
    on<RatingPositionsConfirmed>(_onConfirmed);
    on<RatingAnswerPicked>(
      (event, emit) =>
          emit(state.copyWith(answers: {...state.answers, event.questionId: event.answerId})),
    );
    on<RatingBackToPositions>(
      (event, emit) => emit(state.copyWith(step: RatingQuizStep.positions)),
    );
    on<RatingQuizSubmitted>(_onSubmitted);
  }

  final GetRatingPositions _getPositions;
  final GetRatingQuestions _getQuestions;
  final SubmitRating _submitRating;

  Future<void> _onStarted(RatingQuizStarted event, Emitter<RatingQuizState> emit) async {
    emit(state.copyWith(loading: true));
    final result = await _getPositions(const NoParams());
    result.fold(
      (failure) => emit(state.copyWith(loading: false, error: failure.message)),
      (positions) => emit(state.copyWith(loading: false, positions: positions)),
    );
  }

  void _onToggled(RatingPositionToggled event, Emitter<RatingQuizState> emit) {
    final picked = [...state.picked];
    if (!picked.remove(event.code)) {
      if (picked.length >= RatingQuizState.maxPositions) return;
      picked.add(event.code);
    }
    emit(state.copyWith(picked: picked));
  }

  Future<void> _onConfirmed(RatingPositionsConfirmed event, Emitter<RatingQuizState> emit) async {
    if (state.picked.isEmpty) return;
    emit(state.copyWith(loading: true));
    final result = await _getQuestions(state.picked.first);
    result.fold(
      (failure) => emit(state.copyWith(loading: false, error: failure.message)),
      (questions) => emit(
        state.copyWith(
          loading: false,
          step: RatingQuizStep.questions,
          questions: questions,
          // A new main position means different questions.
          answers: {
            for (final entry in state.answers.entries)
              if (questions.any((question) => question.id == entry.key)) entry.key: entry.value,
          },
        ),
      ),
    );
  }

  Future<void> _onSubmitted(RatingQuizSubmitted event, Emitter<RatingQuizState> emit) async {
    if (!state.allAnswered || state.loading) return;
    emit(state.copyWith(loading: true));
    final result = await _submitRating((
      positions: state.picked,
      answerIds: [for (final question in state.questions) state.answers[question.id]!],
    ));
    result.fold(
      (failure) => emit(state.copyWith(loading: false, error: failure.message)),
      (rating) => emit(state.copyWith(loading: false, step: RatingQuizStep.result, result: rating)),
    );
  }
}
