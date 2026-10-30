import 'package:bloc_test/bloc_test.dart';
import 'package:dummy_shop/features/auth/bloc/session_cubit.dart';
import 'package:dummy_shop/features/auth/data/auth_repository.dart';
import 'package:dummy_shop/features/products/bloc/product_detail_cubit.dart';
import 'package:dummy_shop/features/products/bloc/products_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSessionCubit extends MockCubit<SessionState> implements SessionCubit {}

class MockProductsBloc extends MockBloc<ProductsEvent, ProductsState> implements ProductsBloc {}

class MockProductDetailCubit extends MockCubit<ProductDetailState> implements ProductDetailCubit {}

/// Gives widget tests a tall screen, so content below the fold is built.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
