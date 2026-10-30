import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/features/products/bloc/product_detail_cubit.dart';
import 'package:dummy_shop/features/products/presentation/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mocks.dart';
import '../support/samples.dart';

void main() {
  const offline = NetworkFailure('offline');
  final summary = sampleProduct(1);

  late MockProductDetailCubit cubit;

  setUp(() {
    cubit = MockProductDetailCubit();
    when(() => cubit.load()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester, ProductDetailState state) async {
    useTallScreen(tester);
    when(() => cubit.state).thenReturn(state);
    await tester.pumpWidget(
      BlocProvider<ProductDetailCubit>.value(
        value: cubit,
        child: const MaterialApp(home: ProductDetailPage()),
      ),
    );
  }

  testWidgets('shows what the list knew while the rest loads', (tester) async {
    await pumpPage(tester, ProductDetailState(summary: summary, isLoading: true));

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text(r'$11.00'), findsOneWidget);
    expect(find.byKey(const Key('detail.loading')), findsOneWidget);
  });

  testWidgets('shows the details once they arrive', (tester) async {
    await pumpPage(tester, ProductDetailState(summary: summary, details: sampleDetails(1)));

    expect(find.text('Description of product 1.'), findsOneWidget);
    expect(find.text('Ships in 2 weeks'), findsOneWidget);
    expect(find.text('#mascara'), findsOneWidget);
    expect(find.text('Reviews (1)'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.byKey(const Key('detail.loading')), findsNothing);
  });

  testWidgets('opened from a link, a failure fills the page and retries', (tester) async {
    await pumpPage(tester, const ProductDetailState(failure: offline));

    expect(find.text("Couldn't load this product"), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => cubit.load()).called(1);
  });

  testWidgets('with a summary, a failure stays under it', (tester) async {
    await pumpPage(tester, ProductDetailState(summary: summary, failure: offline));

    expect(find.text('Product 1'), findsOneWidget);
    expect(find.byKey(const Key('detail.error')), findsOneWidget);
    await tester.tap(find.text('Try again'));
    verify(() => cubit.load()).called(1);
  });

  testWidgets('a malformed link says the product was not found', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProductNotFoundPage()));
    expect(find.text('Product not found'), findsOneWidget);
  });
}
