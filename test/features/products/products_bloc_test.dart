import 'package:bloc_test/bloc_test.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/features/products/bloc/products_bloc.dart';
import 'package:dummy_shop/features/products/data/product.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/samples.dart';

void main() {
  const offline = NetworkFailure('offline');

  late FakeProductsRepository repository;

  setUp(() => repository = FakeProductsRepository(total: 45));

  List<ProductSummary> products(int from, int to) => [for (var i = from; i <= to; i++) sampleProduct(i)];

  ProductsState loaded(int count, {int total = 45, int? nextSkip}) => ProductsState(
    status: ProductsStatus.success,
    items: products(1, count),
    total: total,
    nextSkip: nextSkip ?? count,
  );

  group('first load', () {
    blocTest<ProductsBloc, ProductsState>(
      'shows a loader, then the first page',
      build: () => ProductsBloc(repository),
      act: (bloc) => bloc.add(const ProductsStarted()),
      expect: () => [const ProductsState(status: ProductsStatus.loading), loaded(20)],
      verify: (_) => expect(repository.pageCalls, [0]),
    );

    blocTest<ProductsBloc, ProductsState>(
      'an empty catalog is a success with nothing in it',
      setUp: () => repository.catalog = [],
      build: () => ProductsBloc(repository),
      act: (bloc) => bloc.add(const ProductsStarted()),
      expect: () => [
        const ProductsState(status: ProductsStatus.loading),
        isA<ProductsState>().having((s) => s.isEmpty, 'isEmpty', isTrue),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'a failure is shown in place of the list',
      setUp: () => repository.failures.add(offline),
      build: () => ProductsBloc(repository),
      act: (bloc) => bloc.add(const ProductsStarted()),
      expect: () => [
        const ProductsState(status: ProductsStatus.loading),
        const ProductsState(status: ProductsStatus.failure, failure: offline),
      ],
    );
  });

  group('next page', () {
    blocTest<ProductsBloc, ProductsState>(
      'appends the page that starts after the loaded items',
      build: () => ProductsBloc(repository),
      seed: () => loaded(20),
      act: (bloc) => bloc.add(const ProductsNextPageRequested(20)),
      expect: () => [loaded(20).copyWith(isLoadingMore: true), loaded(40)],
      verify: (_) => expect(repository.pageCalls, [20]),
    );

    blocTest<ProductsBloc, ProductsState>(
      'the last, shorter page reaches the end',
      build: () => ProductsBloc(repository),
      seed: () => loaded(40),
      act: (bloc) => bloc.add(const ProductsNextPageRequested(40)),
      skip: 1,
      expect: () => [
        isA<ProductsState>()
            .having((s) => s.items, 'items', hasLength(45))
            .having((s) => s.hasReachedEnd, 'end', isTrue),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'nothing is requested past the end',
      build: () => ProductsBloc(repository),
      seed: () => loaded(45),
      act: (bloc) => bloc.add(const ProductsNextPageRequested(45)),
      expect: () => <ProductsState>[],
      verify: (_) => expect(repository.pageCalls, isEmpty),
    );

    blocTest<ProductsBloc, ProductsState>(
      'a repeated request for the same list loads one page',
      build: () => ProductsBloc(repository),
      seed: () => loaded(20),
      act: (bloc) => bloc
        ..add(const ProductsNextPageRequested(20))
        ..add(const ProductsNextPageRequested(20)),
      expect: () => [loaded(20).copyWith(isLoadingMore: true), loaded(40)],
      verify: (_) => expect(repository.pageCalls, [20]),
    );

    blocTest<ProductsBloc, ProductsState>(
      'a request made for an older list is ignored',
      build: () => ProductsBloc(repository),
      seed: () => loaded(40),
      act: (bloc) => bloc.add(const ProductsNextPageRequested(20)),
      expect: () => <ProductsState>[],
    );

    blocTest<ProductsBloc, ProductsState>(
      'a failure keeps the list, and requests queued before it do not retry',
      setUp: () => repository.failures.add(offline),
      build: () => ProductsBloc(repository),
      seed: () => loaded(20),
      act: (bloc) => bloc
        ..add(const ProductsNextPageRequested(20))
        ..add(const ProductsNextPageRequested(20)),
      expect: () => [loaded(20).copyWith(isLoadingMore: true), loaded(20).copyWith(loadMoreFailure: () => offline)],
      verify: (_) => expect(repository.pageCalls, [20]),
    );

    blocTest<ProductsBloc, ProductsState>(
      'after a failure only an explicit retry loads again',
      build: () => ProductsBloc(repository),
      seed: () => loaded(20).copyWith(loadMoreFailure: () => offline),
      act: (bloc) async {
        bloc.add(const ProductsNextPageRequested(20)); // a scroll: ignored
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProductsNextPageRequested(20, isRetry: true));
      },
      expect: () => [loaded(20).copyWith(isLoadingMore: true), loaded(40)],
      verify: (_) => expect(repository.pageCalls, [20]),
    );

    blocTest<ProductsBloc, ProductsState>(
      'a page with nothing new still moves the list forward',
      // The server repeats the first 20 products at offset 20 (the catalog
      // shifted). Paging by items.length would ask for offset 20 forever.
      setUp: () => repository.catalog = [...products(1, 20), ...products(1, 20), ...products(21, 45)],
      build: () => ProductsBloc(repository),
      seed: () => loaded(20, total: 65),
      act: (bloc) async {
        bloc.add(const ProductsNextPageRequested(20));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProductsNextPageRequested(40));
      },
      expect: () => [
        loaded(20, total: 65).copyWith(isLoadingMore: true),
        loaded(20, total: 65, nextSkip: 40),
        loaded(20, total: 65, nextSkip: 40).copyWith(isLoadingMore: true),
        loaded(40, total: 65, nextSkip: 60),
      ],
      verify: (_) => expect(repository.pageCalls, [20, 40]),
    );

    blocTest<ProductsBloc, ProductsState>(
      'an empty page ends the list even if the total says otherwise',
      setUp: () => repository
        ..catalog = products(1, 20)
        ..reportedTotal = 45,
      build: () => ProductsBloc(repository),
      seed: () => loaded(20),
      act: (bloc) async {
        bloc.add(const ProductsNextPageRequested(20));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProductsNextPageRequested(20));
      },
      expect: () => [
        loaded(20).copyWith(isLoadingMore: true),
        isA<ProductsState>().having((s) => s.hasReachedEnd, 'hasReachedEnd', isTrue),
      ],
      verify: (_) => expect(repository.pageCalls, [20]),
    );

    blocTest<ProductsBloc, ProductsState>(
      'items the list already shows are not added twice',
      // A product was added at the top since the first page: the next page
      // starts one item earlier than before.
      setUp: () => repository.catalog = [sampleProduct(100), ...products(1, 45)],
      build: () => ProductsBloc(repository),
      seed: () => loaded(20),
      act: (bloc) => bloc.add(const ProductsNextPageRequested(20)),
      skip: 1,
      expect: () => [ProductsState(status: ProductsStatus.success, items: products(1, 39), total: 46, nextSkip: 40)],
    );
  });

  group('refresh', () {
    blocTest<ProductsBloc, ProductsState>(
      'replaces the list and tells the indicator it is done',
      setUp: () => repository.catalog = [sampleProduct(100), ...products(1, 45)],
      build: () => ProductsBloc(repository),
      seed: () => loaded(40),
      act: (bloc) async {
        final event = ProductsRefreshed();
        bloc.add(event);
        await event.done.future;
      },
      expect: () => [
        ProductsState(
          status: ProductsStatus.success,
          items: [sampleProduct(100), ...products(1, 19)],
          total: 46,
          nextSkip: 20,
        ),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'a failure keeps the list and is reported once',
      setUp: () => repository.failures.add(offline),
      build: () => ProductsBloc(repository),
      seed: () => loaded(20),
      act: (bloc) async {
        final event = ProductsRefreshed();
        bloc.add(event);
        await event.done.future;
      },
      expect: () => [loaded(20).copyWith(refreshFailure: () => offline)],
    );

    blocTest<ProductsBloc, ProductsState>(
      'after a failed first load it loads again',
      build: () => ProductsBloc(repository),
      seed: () => const ProductsState(status: ProductsStatus.failure, failure: offline),
      act: (bloc) => bloc.add(ProductsRefreshed()),
      expect: () => [const ProductsState(status: ProductsStatus.loading), loaded(20)],
    );

    blocTest<ProductsBloc, ProductsState>(
      'waits for a page in flight instead of racing it',
      build: () => ProductsBloc(repository),
      seed: () => loaded(20),
      act: (bloc) async {
        repository.holdRequests = true;
        bloc
          ..add(const ProductsNextPageRequested(20))
          ..add(ProductsRefreshed());
        // Answer the newest request first: a refresh that is faster than the
        // page before it. Handled concurrently, the slow page would land on
        // the refreshed list and grow it back to 40.
        while (true) {
          await Future<void>.delayed(Duration.zero);
          final open = repository.held.where((c) => !c.isCompleted);
          if (open.isEmpty) break;
          open.last.complete();
        }
      },
      expect: () => [loaded(20).copyWith(isLoadingMore: true), loaded(40), loaded(20)],
      verify: (_) => expect(repository.pageCalls, [20, 0]),
    );
  });
}
