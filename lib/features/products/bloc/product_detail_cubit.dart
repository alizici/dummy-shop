import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../core/network/api_failure.dart';
import '../data/product.dart';
import '../data/products_repository.dart';

class ProductDetailState extends Equatable {
  const ProductDetailState({this.summary, this.details, this.failure, this.isLoading = false});

  /// Known from the list, so the page can show title, price and image at once.
  final ProductSummary? summary;
  final ProductDetails? details;
  final ApiFailure? failure;
  final bool isLoading;

  @override
  List<Object?> get props => [summary, details, failure, isLoading];
}

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit(this._products, {required this.productId, ProductSummary? summary})
    : super(ProductDetailState(summary: summary));

  final ProductsRepository _products;
  final int productId;

  Future<void> load() async {
    if (state.isLoading) return;
    emit(ProductDetailState(summary: state.summary, details: state.details, isLoading: true));
    try {
      final details = await _products.details(productId);
      if (isClosed) return; // the user left the page
      emit(ProductDetailState(summary: details.summary, details: details));
    } on ApiFailure catch (failure) {
      if (isClosed) return;
      emit(ProductDetailState(summary: state.summary, details: state.details, failure: failure));
    }
  }
}
