import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/bloc/session_cubit.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/splash_page.dart';
import '../features/products/bloc/product_detail_cubit.dart';
import '../features/products/bloc/products_bloc.dart';
import '../features/products/data/product.dart';
import '../features/products/data/products_repository.dart';
import '../features/products/presentation/product_detail_page.dart';
import '../features/products/presentation/products_page.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const products = '/products';
  static String product(int id) => '/products/$id';
}

/// Navigation follows the session: one redirect decides who sees what, so no
/// screen checks "am I signed in?" on its own.
GoRouter buildRouter(SessionCubit session) => GoRouter(
  initialLocation: Routes.splash,
  refreshListenable: _StreamListenable(session.stream),
  redirect: (context, state) {
    final location = state.matchedLocation;
    return switch (session.state.status) {
      SessionStatus.unknown => location == Routes.splash ? null : Routes.splash,
      SessionStatus.unauthenticated => location == Routes.login ? null : Routes.login,
      SessionStatus.authenticated => location == Routes.splash || location == Routes.login ? Routes.products : null,
    };
  },
  routes: [
    GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
    GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
    GoRoute(
      path: Routes.products,
      // The list's bloc lives with the route: when the session ends and the
      // user is sent to login, it's disposed with everything it loaded.
      builder: (context, _) => BlocProvider(
        create: (context) => ProductsBloc(context.read<ProductsRepository>())..add(const ProductsStarted()),
        child: const ProductsPage(),
      ),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            if (id == null) return const ProductNotFoundPage();
            final summary = state.extra is ProductSummary ? state.extra! as ProductSummary : null;
            return BlocProvider(
              create: (context) =>
                  ProductDetailCubit(context.read<ProductsRepository>(), productId: id, summary: summary)..load(),
              child: const ProductDetailPage(),
            );
          },
        ),
      ],
    ),
  ],
);

/// Lets GoRouter re-run its redirect whenever the session changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
