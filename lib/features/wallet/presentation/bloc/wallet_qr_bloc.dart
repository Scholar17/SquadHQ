import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/usecases/get_my_wallet_qr.dart';
import '../../domain/usecases/upload_wallet_qr.dart';

sealed class WalletQrEvent extends Equatable {
  const WalletQrEvent();

  @override
  List<Object?> get props => [];
}

final class WalletQrStarted extends WalletQrEvent {
  const WalletQrStarted();
}

final class WalletQrUploadRequested extends WalletQrEvent {
  const WalletQrUploadRequested({required this.bytes, required this.fileExtension});

  final Uint8List bytes;
  final String fileExtension;

  @override
  List<Object?> get props => [bytes, fileExtension];
}

sealed class WalletQrState extends Equatable {
  const WalletQrState();

  @override
  List<Object?> get props => [];
}

final class WalletQrLoading extends WalletQrState {
  const WalletQrLoading();
}

/// [path] is null until the profile uploads a QR.
final class WalletQrLoaded extends WalletQrState {
  const WalletQrLoaded(this.path);

  final String? path;

  @override
  List<Object?> get props => [path];
}

final class WalletQrUploading extends WalletQrState {
  const WalletQrUploading(this.previous);

  final WalletQrState previous;

  @override
  List<Object?> get props => [previous];
}

final class WalletQrFailure extends WalletQrState {
  const WalletQrFailure(this.message, this.previous);

  final String message;
  final WalletQrState previous;

  @override
  List<Object?> get props => [message, previous];
}

/// The profile page's "Wallet QR" section — one instance per visit.
class WalletQrBloc extends Bloc<WalletQrEvent, WalletQrState> {
  WalletQrBloc({
    required GetMyWalletQr getMyWalletQr,
    required UploadWalletQr uploadWalletQr,
  })  : _getMyWalletQr = getMyWalletQr,
        _uploadWalletQr = uploadWalletQr,
        super(const WalletQrLoading()) {
    on<WalletQrStarted>(_onStarted);
    on<WalletQrUploadRequested>(_onUploadRequested);
  }

  final GetMyWalletQr _getMyWalletQr;
  final UploadWalletQr _uploadWalletQr;

  Future<void> _onStarted(WalletQrStarted event, Emitter<WalletQrState> emit) async {
    emit(const WalletQrLoading());
    final result = await _getMyWalletQr(const NoParams());
    result.fold(
      (failure) => emit(WalletQrFailure(failure.message, const WalletQrLoaded(null))),
      (path) => emit(WalletQrLoaded(path)),
    );
  }

  Future<void> _onUploadRequested(
    WalletQrUploadRequested event,
    Emitter<WalletQrState> emit,
  ) async {
    final fallback = switch (state) {
      WalletQrFailure(:final previous) => previous,
      final settled => settled,
    };
    emit(WalletQrUploading(fallback));
    final result = await _uploadWalletQr(
      UploadWalletQrParams(bytes: event.bytes, fileExtension: event.fileExtension),
    );
    result.fold(
      (failure) => emit(WalletQrFailure(failure.message, fallback)),
      (path) => emit(WalletQrLoaded(path)),
    );
  }
}
