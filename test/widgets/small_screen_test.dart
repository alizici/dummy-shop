import 'package:dummy_shop/features/products/bloc/product_detail_cubit.dart';
import 'package:dummy_shop/features/products/data/product.dart';
import 'package:dummy_shop/features/products/presentation/product_detail_page.dart';
import 'package:dummy_shop/features/products/presentation/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../support/mocks.dart';
import '../support/samples.dart';

/// Small phones with large text: the layouts must wrap, not overflow.
/// (The test font is wider than Roboto, so this is stricter than a device.)
void main() {
  // The most expensive DummyJSON product, with a long brand and title.
  final expensive = ProductSummary(
    id: 101,
    title: 'Durango SXT RWD with a very long marketing title',
    category: 'vehicle',
    price: 36999.99,
    discountPercentage: 12.5,
    rating: 4.5,
    stock: 3,
    thumbnailUrl: 'https://cdn.test/101.webp',
    brand: 'Dodge Performance Division',
  );

  const screens = [Size(320, 640), Size(360, 740)];
  const textScales = [1.0, 1.3, 1.5];

  void useScreen(WidgetTester tester, Size size, double textScale) {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  for (final size in screens) {
    for (final scale in textScales) {
      final label = '${size.width.toInt()} dp, text ×$scale';

      testWidgets('product tile fits on $label', (tester) async {
        useScreen(tester, size, scale);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: [
                  ProductTile(product: expensive, onTap: () {}),
                  ProductTile(product: sampleProduct(1, brand: null), onTap: () {}),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('product detail fits on $label', (tester) async {
        useScreen(tester, size, scale);
        final cubit = MockProductDetailCubit();
        when(() => cubit.state).thenReturn(
          ProductDetailState(
            summary: expensive,
            details: ProductDetails(
              summary: expensive,
              description: 'A long description. ' * 10,
              imageUrls: const ['https://cdn.test/101-1.webp'],
              tags: const ['vehicles', 'suv'],
              reviews: sampleDetails(101).reviews,
              availabilityStatus: 'Low Stock',
              shippingInformation: 'Ships overnight',
              warrantyInformation: '3 year warranty',
              returnPolicy: '30 days return policy',
            ),
          ),
        );
        await tester.pumpWidget(
          BlocProvider<ProductDetailCubit>.value(
            value: cubit,
            child: const MaterialApp(home: ProductDetailPage()),
          ),
        );
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
