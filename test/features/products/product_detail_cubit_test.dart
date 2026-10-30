import 'package:bloc_test/bloc_test.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/features/products/bloc/product_detail_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/samples.dart';

void main() {
  const offline = NetworkFailure('offline');
  final summary = sampleProduct(1);

  late FakeProductsRepository repository;

  setUp(() => repository = FakeProductsRepository());

  blocTest<ProductDetailCubit, ProductDetailState>(
    'shows what the list knew while the details load',
    build: () => ProductDetailCubit(repository, productId: 1, summary: summary),
    act: (cubit) => cubit.load(),
    expect: () => [
      ProductDetailState(summary: summary, isLoading: true),
      ProductDetailState(summary: summary, details: sampleDetails(1)),
    ],
  );

  blocTest<ProductDetailCubit, ProductDetailState>(
    'opened from a link, it starts from nothing',
    build: () => ProductDetailCubit(repository, productId: 1),
    act: (cubit) => cubit.load(),
    expect: () => [
      const ProductDetailState(isLoading: true),
      ProductDetailState(summary: summary, details: sampleDetails(1)),
    ],
  );

  blocTest<ProductDetailCubit, ProductDetailState>(
    'a failure keeps the summary and can be retried',
    setUp: () => repository.failures.add(offline),
    build: () => ProductDetailCubit(repository, productId: 1, summary: summary),
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    expect: () => [
      ProductDetailState(summary: summary, isLoading: true),
      ProductDetailState(summary: summary, failure: offline),
      ProductDetailState(summary: summary, isLoading: true),
      ProductDetailState(summary: summary, details: sampleDetails(1)),
    ],
  );

  test('leaving the page while loading does not throw', () async {
    repository.holdRequests = true;
    final cubit = ProductDetailCubit(repository, productId: 1, summary: summary);

    final load = cubit.load();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    repository.held.single.complete();

    await expectLater(load, completes);
  });
}
