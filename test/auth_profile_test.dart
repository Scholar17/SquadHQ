import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:squad_hq/core/error/failures.dart' hide AuthFailure;
import 'package:squad_hq/features/auth/domain/entities/app_user.dart';
import 'package:squad_hq/features/auth/domain/repositories/auth_repository.dart';
import 'package:squad_hq/features/auth/domain/usecases/complete_onboarding.dart';
import 'package:squad_hq/features/auth/domain/usecases/delete_account.dart';
import 'package:squad_hq/features/auth/domain/usecases/sign_in_with_facebook.dart';
import 'package:squad_hq/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:squad_hq/features/auth/domain/usecases/sign_out.dart';
import 'package:squad_hq/features/auth/domain/usecases/update_profile.dart';
import 'package:squad_hq/features/auth/domain/usecases/watch_auth_state.dart';
import 'package:squad_hq/features/auth/domain/validators/onboarding_validators.dart';
import 'package:squad_hq/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:squad_hq/features/auth/presentation/bloc/auth_event.dart';
import 'package:squad_hq/features/auth/presentation/bloc/auth_state.dart';

/// Signed in as [user]; saves profile edits in memory.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.user);

  AppUser user;
  final _changes = StreamController<AppUser?>.broadcast();
  UpdateProfileParams? lastUpdate;

  /// Mention names someone else already has.
  Set<String> taken = {};

  void signIn() => _changes.add(user);

  void signedOut() => _changes.add(null);

  void failToLoad() => _changes.addError(Exception('profile failed'));

  @override
  Stream<AppUser?> get authStateChanges => _changes.stream;

  @override
  Future<Either<Failure, AppUser>> updateProfile(UpdateProfileParams params) async {
    if (taken.contains(params.username)) {
      return const Left(ServerFailure(OnboardingValidators.usernameTaken));
    }
    lastUpdate = params;
    user = AppUser(
      id: user.id,
      name: params.name ?? user.name,
      provider: user.provider,
      avatarUrl: params.avatarBytes != null ? 'https://cdn/avatars/${user.id}/new.jpg' : user.avatarUrl,
      phone: params.phone ?? user.phone,
      username: params.username ?? user.username,
    );
    return Right(user);
  }

  @override
  Future<Either<Failure, AppUser>> completeOnboarding({
    required String userId,
    required String name,
    required String phone,
    required String username,
  }) async {
    if (taken.contains(username)) {
      return const Left(ServerFailure(OnboardingValidators.usernameTaken));
    }
    user = AppUser(id: userId, name: name, provider: user.provider, phone: phone, username: username);
    return Right(user);
  }

  @override
  Future<Either<Failure, Unit>> signInWithFacebook() async => const Right(unit);

  @override
  Future<Either<Failure, Unit>> signInWithGoogle() async => const Right(unit);

  bool deleted = false;

  /// As the real one: the account goes, then the session — a null user.
  @override
  Future<Either<Failure, Unit>> deleteAccount() async {
    deleted = true;
    _changes.add(null);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> signOut() async => const Right(unit);
}

AuthBloc _bloc(_FakeAuthRepository repo) => AuthBloc(
      signInWithFacebook: SignInWithFacebook(repo),
      signInWithGoogle: SignInWithGoogle(repo),
      completeOnboarding: CompleteOnboarding(repo),
      signOut: SignOut(repo),
      watchAuthState: WatchAuthState(repo),
      updateProfile: UpdateProfile(repo),
      deleteAccount: DeleteAccount(repo),
    );

void main() {
  test('Setup: a taken mention name, then another one, finishes setup', () async {
    // Signed in, no phone or mention name yet.
    final repo = _FakeAuthRepository(
      const AppUser(id: 'u1', name: 'Test Player', provider: AuthProvider.google),
    )..taken = {'aungko'};
    final bloc = _bloc(repo);
    addTearDown(bloc.close);
    repo.signIn();
    await expectLater(bloc.stream, emits(isA<AuthNeedsOnboarding>()));

    bloc.add(const AuthOnboardingSubmitted(name: 'Aung Ko', phone: '+66812345678', username: 'aungko'));
    await expectLater(
      bloc.stream,
      emitsThrough(
        isA<AuthFailure>().having((s) => s.message, 'message', OnboardingValidators.usernameTaken),
      ),
    );

    bloc.add(const AuthOnboardingSubmitted(name: 'Aung Ko', phone: '+66812345678', username: 'aungko2'));
    await expectLater(
      bloc.stream,
      emitsThrough(isA<AuthAuthenticated>().having((s) => s.user.username, 'username', 'aungko2')),
    );
  });

  test('Profile: a taken mention name, then another one, saves', () async {
    final repo = _FakeAuthRepository(
      const AppUser(
        id: 'u1',
        name: 'Test Player',
        provider: AuthProvider.google,
        phone: '+66812345678',
        username: 'tester',
      ),
    )..taken = {'aungko'};
    final bloc = _bloc(repo);
    addTearDown(bloc.close);
    repo.signIn();
    await expectLater(bloc.stream, emits(isA<AuthAuthenticated>()));

    bloc.add(const AuthProfileUpdateRequested(username: 'aungko'));
    await expectLater(bloc.stream, emitsThrough(isA<AuthFailure>()));

    bloc.add(const AuthProfileUpdateRequested(username: 'aungko2'));
    await expectLater(
      bloc.stream,
      emitsThrough(isA<AuthAuthenticated>().having((s) => s.user.username, 'username', 'aungko2')),
    );
  });

  test('Editing your profile saves name, phone and photo, and stays signed in', () async {
    final repo = _FakeAuthRepository(
      const AppUser(
        id: 'u1',
        name: 'Test Player',
        provider: AuthProvider.google,
        phone: '+66812345678',
        username: 'tester',
      ),
    );
    final bloc = AuthBloc(
      signInWithFacebook: SignInWithFacebook(repo),
      signInWithGoogle: SignInWithGoogle(repo),
      completeOnboarding: CompleteOnboarding(repo),
      signOut: SignOut(repo),
      watchAuthState: WatchAuthState(repo),
      updateProfile: UpdateProfile(repo),
      deleteAccount: DeleteAccount(repo),
    );
    addTearDown(bloc.close);
    repo.signIn();
    await expectLater(bloc.stream, emits(isA<AuthAuthenticated>()));

    bloc.add(
      AuthProfileUpdateRequested(
        name: 'Thaw Zin',
        phone: '+66899999999',
        avatarBytes: Uint8List.fromList([1, 2, 3]),
        avatarExtension: 'jpg',
      ),
    );
    // Loading keeps you signed in underneath; then you, as saved.
    await expectLater(
      bloc.stream,
      emitsInOrder([
        isA<AuthLoading>().having((s) => s.previous, 'previous', isA<AuthAuthenticated>()),
        isA<AuthAuthenticated>()
            .having((s) => s.user.name, 'name', 'Thaw Zin')
            .having((s) => s.user.phone, 'phone', '+66899999999')
            .having((s) => s.user.avatarUrl, 'avatar', 'https://cdn/avatars/u1/new.jpg'),
      ]),
    );
    expect(repo.lastUpdate?.userId, 'u1');
  });

  test('Deleting your account signs you out', () async {
    final repo = _FakeAuthRepository(
      const AppUser(
        id: 'u1',
        name: 'Test Player',
        provider: AuthProvider.google,
        phone: '+66812345678',
        username: 'tester',
      ),
    );
    final bloc = AuthBloc(
      signInWithFacebook: SignInWithFacebook(repo),
      signInWithGoogle: SignInWithGoogle(repo),
      completeOnboarding: CompleteOnboarding(repo),
      signOut: SignOut(repo),
      watchAuthState: WatchAuthState(repo),
      updateProfile: UpdateProfile(repo),
      deleteAccount: DeleteAccount(repo),
    );
    addTearDown(bloc.close);
    repo.signIn();
    await expectLater(bloc.stream, emits(isA<AuthAuthenticated>()));

    bloc.add(const AuthAccountDeletionRequested());
    await expectLater(bloc.stream, emitsInOrder([isA<AuthLoading>(), isA<AuthInitial>()]));
    expect(repo.deleted, isTrue);
  });
}
