import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/bloc/sequential.dart';
import '../../../core/network/api_failure.dart';
import '../data/product.dart';
import '../data/products_repository.dart';

sealed class ProductsEvent {
  const ProductsEvent();
}

/// First load, and "try again" after a failed first load.
final class ProductsStarted extends ProductsEvent {
  const ProductsStarted();
}

/// Pull to refresh. [done] completes when the refresh is over, so the
/// refresh indicator can stop at the right moment.
final class ProductsRefreshed extends ProductsEvent {
  ProductsRefreshed([Completer<void>? done]) : done = done ?? Completer<void>();
  final Completer<void> done;
}

/// The user scrolled near the end of the list, whose next page starts at
/// [nextSkip] (the state's `nextSkip` when the request was made).
///
/// Carrying the offset makes duplicate requests harmless: a request made for
/// a list that has moved on (or been refreshed) since is simply ignored. After
/// a failed page only an explicit [isRetry] loads again, so requests that were
/// already queued don't retry on their own.
final class ProductsNextPageRequested extends ProductsEvent {
  const ProductsNextPageRequested(this.nextSkip, {this.isRetry = false});
  final int nextSkip;
  final bool isRetry;
}

enum ProductsStatus { initial, loading, success, failure }

class ProductsState extends Equatable {
  const ProductsState({
    this.status = ProductsStatus.initial,
    this.items = const [],
    this.total = 0,
    this.nextSkip = 0,
    this.failure,
    this.isLoadingMore = false,
    this.loadMoreFailure,
    this.refreshFailure,
  });

  final ProductsStatus status;
  final List<ProductSummary> items;

  /// Total number of products on the server.
  final int total;

  /// Where the next page starts on the server. Not `items.length`: items
  /// already shown are skipped when appending, so the two can differ.
  final int nextSkip;

  /// Why the first load failed (status [ProductsStatus.failure]).
  final ApiFailure? failure;

  final bool isLoadingMore;

  /// Why the last "next page" failed; the list stays and offers a retry.
  final ApiFailure? loadMoreFailure;

  /// Why the last refresh failed; the list stays and a message is shown.
  final ApiFailure? refreshFailure;

  bool get isEmpty => status == ProductsStatus.success && items.isEmpty;
  bool get hasReachedEnd => status == ProductsStatus.success && nextSkip >= total;

  ProductsState copyWith({
    ProductsStatus? status,
    List<ProductSummary>? items,
    int? total,
    int? nextSkip,
    ApiFailure? Function()? failure,
    bool? isLoadingMore,
    ApiFailure? Function()? loadMoreFailure,
    ApiFailure? Function()? refreshFailure,
  }) => ProductsState(
    status: status ?? this.status,
    items: items ?? this.items,
    total: total ?? this.total,
    nextSkip: nextSkip ?? this.nextSkip,
    failure: failure == null ? this.failure : failure(),
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: loadMoreFailure == null ? this.loadMoreFailure : loadMoreFailure(),
    refreshFailure: refreshFailure == null ? this.refreshFailure : refreshFailure(),
  );

  @override
  List<Object?> get props => [status, items, total, nextSkip, failure, isLoadingMore, loadMoreFailure, refreshFailure];
}

/// The product list: first load, pull to refresh and infinite scroll.
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc(this._products) : super(const ProductsState()) {
    on<ProductsEvent>(
      (event, emit) => switch (event) {
        ProductsStarted() => _load(emit),
        ProductsRefreshed() => _refresh(event, emit),
        ProductsNextPageRequested() => _loadMore(event, emit),
      },
      transformer: sequential(),
    );
  }

  final ProductsRepository _products;

  Future<void> _load(Emitter<ProductsState> emit) async {
    emit(const ProductsState(status: ProductsStatus.loading));
    try {
      emit(_firstPage(await _products.page()));
    } on ApiFailure catch (failure) {
      emit(ProductsState(status: ProductsStatus.failure, failure: failure));
    }
  }

  Future<void> _refresh(ProductsRefreshed event, Emitter<ProductsState> emit) async {
    try {
      if (state.status != ProductsStatus.success) return await _load(emit);
      // Keep showing the current list while the fresh one loads.
      try {
        emit(_firstPage(await _products.page()));
      } on ApiFailure catch (failure) {
        emit(state.copyWith(refreshFailure: () => failure));
      }
    } finally {
      if (!event.done.isCompleted) event.done.complete();
    }
  }

  Future<void> _loadMore(ProductsNextPageRequested event, Emitter<ProductsState> emit) async {
    final ignore =
        state.status != ProductsStatus.success ||
        state.hasReachedEnd ||
        state.isLoadingMore ||
        event.nextSkip != state.nextSkip ||
        (state.loadMoreFailure != null && !event.isRetry);
    if (ignore) return;

    emit(state.copyWith(isLoadingMore: true, loadMoreFailure: () => null, refreshFailure: () => null));
    try {
      final page = await _products.page(skip: state.nextSkip);
      // Skip anything already shown, in case the catalog shifted between pages.
      final known = {for (final p in state.items) p.id};
      final fresh = page.items.where((p) => !known.contains(p.id));
      emit(
        state.copyWith(
          items: [...state.items, ...fresh],
          total: _totalAfter(page),
          nextSkip: page.skip + page.items.length,
          isLoadingMore: false,
        ),
      );
    } on ApiFailure catch (failure) {
      emit(state.copyWith(isLoadingMore: false, loadMoreFailure: () => failure));
    }
  }

  static ProductsState _firstPage(ProductPage page) => ProductsState(
    status: ProductsStatus.success,
    items: page.items,
    total: _totalAfter(page),
    nextSkip: page.skip + page.items.length,
  );

  /// An empty page ends the list whatever `total` says, so a server that
  /// over-reports its total can't make the list ask for the same page forever.
  static int _totalAfter(ProductPage page) => page.items.isEmpty ? page.skip : page.total;
}
