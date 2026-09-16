import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Standard clean-architecture use-case contract: [Type] is the success
/// value, [Params] is the input. Use [NoParams] when a use case takes none.
abstract interface class UseCase<Result, Params> {
  Future<Either<Failure, Result>> call(Params params);
}

final class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
