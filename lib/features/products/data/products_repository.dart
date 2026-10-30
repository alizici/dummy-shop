import 'package:dio/dio.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/network/api_failure.dart';
import 'product.dart';

/// DummyJSON products. Every method throws an ApiFailure on error.
class ProductsRepository {
  ProductsRepository(this._dio);

  final Dio _dio;

  static const pageSize = 20;

  /// The page that starts after [skip] products.
  Future<ProductPage> page({int skip = 0, int limit = pageSize}) => guardApi(() async {
    final response = await _dio.get<Object?>(
      '/products',
      queryParameters: {'limit': limit, 'skip': skip, 'select': ProductSummary.fields.join(',')},
    );
    return ProductPage.fromJson(JsonReader.root(response.data));
  });

  Future<ProductDetails> details(int id) => guardApi(() async {
    final response = await _dio.get<Object?>('/products/$id');
    return ProductDetails.fromJson(JsonReader.root(response.data));
  });
}
