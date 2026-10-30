import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/core/session/session_end.dart';
import 'package:dummy_shop/features/auth/bloc/session_cubit.dart';
import 'package:dummy_shop/features/auth/data/auth_repository.dart';
import 'package:dummy_shop/features/auth/data/auth_user.dart';
import 'package:dummy_shop/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mocks.dart';
import '../support/samples.dart';

void main() {
  late MockAuthRepository auth;
  late MockSessionCubit session;

  const username = Key('login.username');
  const password = Key('login.password');
  const submit = Key('login.submit');

  setUpAll(() => registerFallbackValue(emily));

  setUp(() {
    auth = MockAuthRepository();
    session = MockSessionCubit();
    when(() => session.state).thenReturn(const SessionState.unauthenticated());
  });

  Future<void> pumpLogin(WidgetTester tester) => tester.pumpWidget(
    RepositoryProvider<AuthRepository>.value(
      value: auth,
      child: BlocProvider<SessionCubit>.value(
        value: session,
        child: const MaterialApp(home: LoginPage()),
      ),
    ),
  );

  void loginAnswers(Future<AuthUser> Function() answer) => when(
    () => auth.login(
      username: any(named: 'username'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  testWidgets('asks for both fields before calling the server', (tester) async {
    await pumpLogin(tester);
    await tester.tap(find.byKey(submit));
    await tester.pump();

    expect(find.text('Enter your username'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    verifyNever(
      () => auth.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('explains a wrong password', (tester) async {
    loginAnswers(() => throw const InvalidCredentialsFailure('HTTP 400'));
    await pumpLogin(tester);

    await tester.enterText(find.byKey(username), 'emilys');
    await tester.enterText(find.byKey(password), 'wrong');
    await tester.tap(find.byKey(submit));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byKey(const Key('login.error')), matching: find.text('Wrong username or password.')),
      findsOneWidget,
    );
    verifyNever(() => session.signedIn(any()));
  });

  testWidgets('hands the signed-in user to the session', (tester) async {
    loginAnswers(() async => emily);
    await pumpLogin(tester);

    await tester.enterText(find.byKey(username), 'emilys');
    await tester.enterText(find.byKey(password), 'emilyspass');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    verify(() => session.signedIn(emily)).called(1);
  });

  testWidgets('the test account button fills in emilys and signs in', (tester) async {
    loginAnswers(() async => emily);
    await pumpLogin(tester);

    await tester.tap(find.text('Use test account (emilys)'));
    await tester.pumpAndSettle();

    verify(() => auth.login(username: 'emilys', password: 'emilyspass')).called(1);
  });

  testWidgets('the password can be shown', (tester) async {
    await pumpLogin(tester);
    EditableText passwordField() =>
        tester.widget<EditableText>(find.descendant(of: find.byKey(password), matching: find.byType(EditableText)));

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);
  });

  testWidgets('says why the user is back here after an expired session', (tester) async {
    when(() => session.state).thenReturn(const SessionState.unauthenticated(SessionEnd.expired));
    await pumpLogin(tester);
    expect(find.text('Your session expired. Please sign in again.'), findsOneWidget);
  });

  testWidgets('says nothing after a normal sign-out', (tester) async {
    when(() => session.state).thenReturn(const SessionState.unauthenticated(SessionEnd.loggedOut));
    await pumpLogin(tester);
    expect(find.textContaining('expired'), findsNothing);
  });
}
