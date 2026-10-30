import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/core/session/session_tokens.dart';
import 'package:dummy_shop/features/auth/data/auth_user.dart';
import 'package:dummy_shop/features/products/data/product.dart';
import 'package:dummy_shop/features/products/data/products_repository.dart';

/// A real DummyJSON response saved under `test/fixtures/`.
Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, Object?>;

/// An unsigned JWT that expires at [expiresAt], shaped like DummyJSON's.
String fakeJwt({required DateTime expiresAt, String subject = 'emilys'}) {
  String part(Map<String, Object?> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp = expiresAt.millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': subject, 'exp': exp})}.signature';
}

const emily = AuthUser(
  id: 1,
  username: 'emilys',
  firstName: 'Emily',
  lastName: 'Johnson',
  imageUrl: 'https://dummyjson.com/icon/emilys/128',
);

Map<String, Object?> userJson() => {
  'id': 1,
  'username': 'emilys',
  'email': 'emily.johnson@x.dummyjson.com',
  'firstName': 'Emily',
  'lastName': 'Johnson',
  'gender': 'female',
  'image': 'https://dummyjson.com/icon/emilys/128',
};

/// The body of a successful `POST /auth/login`.
Map<String, Object?> loginJson({required String accessToken, required String refreshToken}) => {
  ...userJson(),
  'accessToken': accessToken,
  'refreshToken': refreshToken,
};

/// Session tokens whose access token is a real JWT valid for [validFor].
SessionTokens sessionTokens(String name, {Duration validFor = const Duration(minutes: 30), DateTime? now}) {
  final expiresAt = (now ?? DateTime.now()).add(validFor);
  return SessionTokens(
    accessToken: fakeJwt(expiresAt: expiresAt, subject: name),
    refreshToken: 'refresh-$name',
    accessExpiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt.millisecondsSinceEpoch ~/ 1000 * 1000, isUtc: true),
  );
}

ProductSummary sampleProduct(int id, {String? brand = 'Brand', double? price}) => ProductSummary(
  id: id,
  title: 'Product $id',
  category: 'beauty',
  price: price ?? 10.0 + id,
  discountPercentage: 10,
  rating: 4.5,
  stock: 5,
  thumbnailUrl: 'https://cdn.test/$id.webp',
  brand: brand,
);

Map<String, Object?> sampleProductJson(int id) => {
  'id': id,
  'title': 'Product $id',
  'category': 'beauty',
  'price': 10 + id,
  'discountPercentage': 10,
  'rating': 4.5,
  'stock': 5,
  'thumbnail': 'https://cdn.test/$id.webp',
  'brand': 'Brand',
};

ProductDetails sampleDetails(int id) => ProductDetails(
  summary: sampleProduct(id),
  description: 'Description of product $id.',
  imageUrls: ['https://cdn.test/$id-1.webp', 'https://cdn.test/$id-2.webp'],
  tags: const ['beauty', 'mascara'],
  reviews: [Review(rating: 5, comment: 'Great!', reviewerName: 'Ada Lovelace', date: DateTime.utc(2025, 4, 30))],
  availabilityStatus: 'In Stock',
  shippingInformation: 'Ships in 2 weeks',
  warrantyInformation: '1 month warranty',
  returnPolicy: 'No return policy',
);

/// A products repository over an in-memory catalog, with scripted failures.
class FakeProductsRepository implements ProductsRepository {
  FakeProductsRepository({int total = 45}) : catalog = [for (var i = 1; i <= total; i++) sampleProduct(i)];

  List<ProductSummary> catalog;

  /// Overrides the `total` the fake server reports (default: the catalog size).
  int? reportedTotal;

  /// The `skip` of every page request, in order.
  final pageCalls = <int>[];

  /// Thrown by the next calls, one each, before the catalog is used.
  final failures = <ApiFailure>[];

  /// When true, each request waits in [held] until the test completes it, so
  /// a test can decide in which order responses arrive.
  bool holdRequests = false;
  final held = <Completer<void>>[];

  Future<void> _maybeHold() async {
    if (!holdRequests) return;
    final release = Completer<void>();
    held.add(release);
    await release.future;
  }

  @override
  Future<ProductPage> page({int skip = 0, int limit = ProductsRepository.pageSize}) async {
    pageCalls.add(skip);
    await _maybeHold();
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return ProductPage(
      items: catalog.skip(skip).take(limit).toList(),
      total: reportedTotal ?? catalog.length,
      skip: skip,
    );
  }

  @override
  Future<ProductDetails> details(int id) async {
    await _maybeHold();
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return sampleDetails(id);
  }
}
