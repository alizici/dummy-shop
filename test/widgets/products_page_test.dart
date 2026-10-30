import 'package:bloc_test/bloc_test.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/features/auth/bloc/session_cubit.dart';
import 'package:dummy_shop/features/auth/data/auth_user.dart';
import 'package:dummy_shop/features/products/bloc/products_bloc.dart';
import 'package:dummy_shop/features/products/presentation/products_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mocks.dart';
import '../support/samples.dart';

void main() {
  const offline = NetworkFailure('offline');
  const offlineText = 'No connection. Check your internet and try again.';

  late MockProductsBloc bloc;
  late MockSessionCubit session;

  setUpAll(() => registerFallbackValue(const ProductsStarted()));

  setUp(() {
    bloc = MockProductsBloc();
    session = MockSessionCubit();
    when(() => session.state).thenReturn(
      const SessionState.authenticated(AuthUser(id: 1, username: 'emilys', firstName: 'Emily', lastName: 'Johnson')),
    );
    when(() => session.logout()).thenAnswer((_) async {});
  });

  ProductsState loaded(int count, {int total = 45}) => ProductsState(
    status: ProductsStatus.success,
    items: [for (var i = 1; i <= count; i++) sampleProduct(i)],
    total: total,
    nextSkip: count,
  );

  Future<void> pumpPage(WidgetTester tester, ProductsState state) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<SessionCubit>.value(value: session),
          BlocProvider<ProductsBloc>.value(value: bloc),
        ],
        child: const MaterialApp(home: ProductsPage()),
      ),
    );
  }

  List<ProductsEvent> sentEvents() => verify(() => bloc.add(captureAny())).captured.cast<ProductsEvent>();

  testWidgets('shows a loader on the first load', (tester) async {
    await pumpPage(tester, const ProductsState(status: ProductsStatus.loading));
    expect(find.byKey(const Key('products.loading')), findsOneWidget);
  });

  testWidgets('a failed first load explains and retries', (tester) async {
    await pumpPage(tester, const ProductsState(status: ProductsStatus.failure, failure: offline));

    expect(find.byKey(const Key('products.error')), findsOneWidget);
    expect(find.text(offlineText), findsOneWidget);

    await tester.tap(find.text('Try again'));
    expect(sentEvents().single, isA<ProductsStarted>());
  });

  testWidgets('an empty catalog says so', (tester) async {
    await pumpPage(tester, const ProductsState(status: ProductsStatus.success));
    expect(find.byKey(const Key('products.empty')), findsOneWidget);
  });

  testWidgets('lists the products and marks the end', (tester) async {
    await pumpPage(tester, loaded(3, total: 3));

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 3'), findsOneWidget);
    expect(find.text("You've seen all 3 products"), findsOneWidget);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('a first page shorter than the screen asks for more by itself', (tester) async {
    await pumpPage(tester, loaded(3));
    await tester.pump();

    expect(sentEvents().whereType<ProductsNextPageRequested>().first.nextSkip, 3);
  });

  testWidgets('a long list asks for the next page only near the end', (tester) async {
    await pumpPage(tester, loaded(20));
    await tester.pump();
    verifyNever(() => bloc.add(any()));

    await tester.drag(find.byKey(const Key('products.list')), const Offset(0, -2000));
    await tester.pump();

    expect(sentEvents().whereType<ProductsNextPageRequested>().first.nextSkip, 20);
  });

  testWidgets('a failed next page offers a retry under the list', (tester) async {
    await pumpPage(tester, loaded(3).copyWith(loadMoreFailure: () => offline));
    await tester.pump();
    verifyNever(() => bloc.add(any())); // no automatic retry loop

    await tester.tap(
      find.descendant(of: find.byKey(const Key('products.loadMoreError')), matching: find.text('Try again')),
    );
    final retry = sentEvents().whereType<ProductsNextPageRequested>().single;
    expect((retry.nextSkip, retry.isRetry), (3, true));
  });

  testWidgets('pull to refresh waits for the bloc to finish', (tester) async {
    await pumpPage(tester, loaded(3, total: 3));

    await tester.fling(find.byKey(const Key('products.list')), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final refresh = sentEvents().whereType<ProductsRefreshed>().single;
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);

    refresh.done.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RefreshProgressIndicator), findsNothing);
  });

  testWidgets('a failed refresh keeps the list and shows a message', (tester) async {
    final failed = loaded(3, total: 3).copyWith(refreshFailure: () => offline);
    whenListen(bloc, Stream.value(failed), initialState: loaded(3, total: 3));
    await pumpPage(tester, loaded(3, total: 3));
    await tester.pump();

    expect(find.descendant(of: find.byType(SnackBar), matching: find.text(offlineText)), findsOneWidget);
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('sign out goes through the session', (tester) async {
    await pumpPage(tester, loaded(3, total: 3));
    await tester.tap(find.byKey(const Key('products.logout')));
    verify(() => session.logout()).called(1);
  });
}
