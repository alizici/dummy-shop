import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dummy_shop/core/session/session_end.dart';
import 'package:dummy_shop/features/auth/bloc/session_cubit.dart';
import 'package:dummy_shop/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/samples.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository auth;
  late StreamController<SessionEnd> ended;

  setUp(() {
    auth = MockAuthRepository();
    ended = StreamController<SessionEnd>.broadcast();
    when(() => auth.sessionEnded).thenAnswer((_) => ended.stream);
  });

  tearDown(() => ended.close());

  test('starts unknown, so the app shows the splash until restore answers', () {
    expect(SessionCubit(auth).state, const SessionState.unknown());
  });

  group('restore', () {
    blocTest<SessionCubit, SessionState>(
      'an active session signs the user in',
      setUp: () => when(() => auth.restore()).thenAnswer((_) async => const ActiveSession(emily)),
      build: () => SessionCubit(auth),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionState.authenticated(emily)],
    );

    blocTest<SessionCubit, SessionState>(
      'an unverified session still signs the user in',
      setUp: () => when(() => auth.restore()).thenAnswer((_) async => const UnverifiedSession()),
      build: () => SessionCubit(auth),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionState.authenticated()],
    );

    blocTest<SessionCubit, SessionState>(
      'no session goes to sign-in',
      setUp: () => when(() => auth.restore()).thenAnswer((_) async => const NoSession()),
      build: () => SessionCubit(auth),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionState.unauthenticated()],
    );

    blocTest<SessionCubit, SessionState>(
      'a session rejected during the check keeps "expired" as the reason',
      setUp: () => when(() => auth.restore()).thenAnswer((_) async {
        ended.add(SessionEnd.expired);
        await Future<void>.delayed(Duration.zero);
        return const NoSession();
      }),
      build: () => SessionCubit(auth),
      act: (cubit) => cubit.restore(),
      expect: () => [const SessionState.unauthenticated(SessionEnd.expired)],
    );
  });

  blocTest<SessionCubit, SessionState>(
    'a session that ends anywhere in the app signs the user out',
    build: () => SessionCubit(auth),
    seed: () => const SessionState.authenticated(emily),
    act: (_) => ended.add(SessionEnd.expired),
    expect: () => [const SessionState.unauthenticated(SessionEnd.expired)],
  );

  blocTest<SessionCubit, SessionState>(
    'signedIn hands the user to the session',
    build: () => SessionCubit(auth),
    act: (cubit) => cubit.signedIn(emily),
    expect: () => [const SessionState.authenticated(emily)],
  );

  blocTest<SessionCubit, SessionState>(
    'logout asks the repository, whose ended event then signs the user out',
    setUp: () => when(() => auth.logout()).thenAnswer((_) async => ended.add(SessionEnd.loggedOut)),
    build: () => SessionCubit(auth),
    seed: () => const SessionState.authenticated(emily),
    act: (cubit) => cubit.logout(),
    expect: () => [const SessionState.unauthenticated(SessionEnd.loggedOut)],
    verify: (_) => verify(() => auth.logout()).called(1),
  );
}
