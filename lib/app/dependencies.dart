import 'package:dio/dio.dart';

import '../core/network/auth_interceptor.dart';
import '../core/session/session_manager.dart';
import '../core/session/token_storage.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/products/data/products_repository.dart';
import '../platform/secure_token_storage.dart';

/// The composition root: the only place that knows how the app is wired.
///
/// Two Dio clients on purpose:
/// - `public` has no auth logic (login, refresh). Refresh must never pass
///   through the auth interceptor, or a failing refresh would refresh itself.
/// - `authorized` attaches the session token and recovers from a 401.
class AppDependencies {
  AppDependencies._({required this.session, required this.auth, required this.products});

  /// [storage] and [httpClientAdapter] are for tests: an in-memory store and
  /// a fake server instead of the keychain and the network.
  factory AppDependencies.create({
    TokenStorage? storage,
    HttpClientAdapter? httpClientAdapter,
    String baseUrl = 'https://dummyjson.com',
  }) {
    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    final public = Dio(options);
    final authorized = Dio(options);
    if (httpClientAdapter != null) {
      public.httpClientAdapter = httpClientAdapter;
      authorized.httpClientAdapter = httpClientAdapter;
    }

    late final AuthApi authApi;
    final session = SessionManager(
      storage: storage ?? SecureTokenStorage(),
      refresher: (refreshToken) => authApi.refresh(refreshToken),
    );
    authorized.interceptors.add(AuthInterceptor(session: session, retryClient: authorized));
    authApi = AuthApi(public: public, authorized: authorized);

    return AppDependencies._(
      session: session,
      auth: AuthRepository(api: authApi, session: session),
      products: ProductsRepository(authorized),
    );
  }

  final SessionManager session;
  final AuthRepository auth;
  final ProductsRepository products;
}
