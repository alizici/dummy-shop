import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/features/auth/bloc/login_cubit.dart';
import 'package:dummy_shop/features/auth/data/auth_repository.dart';
import 'package:dummy_shop/features/auth/data/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/samples.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository());

  void loginAnswers(Future<AuthUser> Function() answer) => when(
    () => auth.login(
      username: any(named: 'username'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  blocTest<LoginCubit, LoginState>(
    'a successful sign-in carries the user',
    setUp: () => loginAnswers(() async => emily),
    build: () => LoginCubit(auth),
    act: (cubit) => cubit.submit(username: 'emilys', password: 'emilyspass'),
    expect: () => [
      const LoginState(status: LoginStatus.submitting),
      const LoginState(status: LoginStatus.success, user: emily),
    ],
    verify: (_) => verify(() => auth.login(username: 'emilys', password: 'emilyspass')).called(1),
  );

  const wrong = InvalidCredentialsFailure('HTTP 400');

  blocTest<LoginCubit, LoginState>(
    'a failure is kept for the page to explain',
    setUp: () => loginAnswers(() => throw wrong),
    build: () => LoginCubit(auth),
    act: (cubit) => cubit.submit(username: 'emilys', password: 'nope'),
    expect: () => [
      const LoginState(status: LoginStatus.submitting),
      const LoginState(status: LoginStatus.failure, failure: wrong),
    ],
  );

  blocTest<LoginCubit, LoginState>(
    'a second tap while signing in is ignored',
    setUp: () => loginAnswers(() async => emily),
    build: () => LoginCubit(auth),
    act: (cubit) {
      unawaited(cubit.submit(username: 'emilys', password: 'emilyspass'));
      unawaited(cubit.submit(username: 'emilys', password: 'emilyspass'));
    },
    expect: () => [
      const LoginState(status: LoginStatus.submitting),
      const LoginState(status: LoginStatus.success, user: emily),
    ],
    verify: (_) => verify(() => auth.login(username: 'emilys', password: 'emilyspass')).called(1),
  );

  test('leaving the page during sign-in does not throw', () async {
    final answer = Completer<AuthUser>();
    loginAnswers(() => answer.future);
    final cubit = LoginCubit(auth);

    final submit = cubit.submit(username: 'emilys', password: 'emilyspass');
    await cubit.close();
    answer.complete(emily);

    await expectLater(submit, completes);
  });
}
