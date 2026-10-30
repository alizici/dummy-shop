import 'package:dummy_shop/app/dependencies.dart';
import 'package:dummy_shop/core/json/json_reader.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:dummy_shop/core/session/token_storage.dart';
import 'package:dummy_shop/features/products/data/product.dart';
import 'package:dummy_shop/features/products/data/products_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_server.dart';
import '../../support/samples.dart';

void main() {
  group('parsing real DummyJSON responses', () {
    test('a list page (with select)', () {
      final page = ProductPage.fromJson(JsonReader.root(fixture('products_page.json')));

      expect(page.total, 194);
      expect(page.skip, 0);
      expect(page.items.map((p) => p.id), [1, 2, 3]);
      expect(page.items.first.title, 'Essence Mascara Lash Princess');
      expect(page.items.first.brand, 'Essence');
    });

    test('a product with everything the detail page shows', () {
      final details = ProductDetails.fromJson(JsonReader.root(fixture('product_1.json')));

      expect(details.summary.id, 1);
      expect(details.description, startsWith('The Essence Mascara Lash Princess'));
      expect(details.imageUrls, isNotEmpty);
      expect(details.tags, contains('mascara'));
      expect(details.reviews, hasLength(3));
      expect(details.reviews.first.date.isUtc, isTrue);
      expect(details.returnPolicy, isNotNull);
    });

    test('a product without a brand (DummyJSON leaves it out for groceries)', () {
      final json = fixture('product_1.json')..remove('brand');
      expect(ProductSummary.fromJson(JsonReader.root(json)).brand, isNull);
    });

    test('a broken item names the exact field', () {
      final json = fixture('products_page.json');
      ((json['products']! as List<Object?>)[2]! as Map<String, Object?>)['price'] = '9.99';

      expect(
        () => ProductPage.fromJson(JsonReader.root(json)),
        throwsA(isA<ResponseFormatException>().having((e) => e.path, 'path', r'$.products[2].price')),
      );
    });

    test('the select list asks only for what the summary reads', () {
      final page = fixture('products_page.json');
      final first = (page['products']! as List<Object?>).first! as Map<String, Object?>;
      expect(first.keys.toSet(), ProductSummary.fields.toSet());
    });
  });

  group('ProductsRepository', () {
    late FakeServer server;
    late ProductsRepository products;

    setUp(() async {
      server = FakeServer();
      final dependencies = AppDependencies.create(
        storage: InMemoryTokenStorage(sessionTokens('emily')),
        httpClientAdapter: server,
      );
      products = dependencies.products;
    });

    test('asks for one page of summaries, with the session token', () async {
      server.reply('GET', '/products', 200, fixture('products_page.json'));

      await products.page(skip: 40);

      final request = server.requests.single;
      expect(request.uri.queryParameters, {
        'limit': '${ProductsRepository.pageSize}',
        'skip': '40',
        'select': ProductSummary.fields.join(','),
      });
      expect(bearerOf(request), startsWith('Bearer '));
    });

    test('loads one product', () async {
      server.reply('GET', '/products/1', 200, fixture('product_1.json'));
      expect((await products.details(1)).summary.title, 'Essence Mascara Lash Princess');
    });

    test('a missing product is a server failure with its message', () async {
      server.reply('GET', '/products/999', 404, {'message': "Product with id '999' not found"});
      await expectLater(
        products.details(999),
        throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 404)),
      );
    });

    test('a malformed body is an invalid response, not a crash', () async {
      server.reply('GET', '/products', 200, {'items': <Object?>[]});
      await expectLater(products.page(), throwsA(isA<InvalidResponseFailure>()));
    });
  });
}
