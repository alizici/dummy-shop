import 'package:dio/dio.dart';

import '../session/session_manager.dart';
import 'api_failure.dart';

/// Adds the session token to requests and recovers from expired tokens.
///
/// - Before a request: a token that is about to expire is refreshed first.
/// - After a 401: the token is refreshed once and the request is retried once.
///   A second 401 is final.
/// - A rejected refresh ends the session (SessionManager); a refresh that
///   fails for any other reason surfaces as a NetworkFailure and the user
///   stays signed in.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required SessionManager session, required Dio retryClient})
    : _session = session,
      _retryClient = retryClient;

  final SessionManager _session;
  final Dio _retryClient;

  static const _retriedKey = 'auth.retried';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final tokens = await _session.usable();
      if (tokens != null) options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
      handler.next(options);
    } on RefreshRejected {
      handler.reject(_failure(options, const UnauthorizedFailure('session expired')));
    } on Exception catch (error) {
      handler.reject(_failure(options, ApiFailure.from(error)));
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final sentToken = _bearer(request);
    if (err.response?.statusCode != 401 || request.extra[_retriedKey] == true || sentToken == null) {
      return handler.next(err);
    }
    try {
      final current = await _session.current();
      if (current == null) return handler.next(err);
      // Refresh only if the request went out with the current token; if not,
      // another request already refreshed and the retry just uses the result.
      if (current.accessToken == sentToken) await _session.refresh(current);
      // The retry passes through [onRequest] again, which attaches the new token.
      final retry = request.copyWith(extra: {...request.extra, _retriedKey: true});
      handler.resolve(await _retryClient.fetch<Object?>(retry));
    } on RefreshRejected {
      handler.reject(_failure(request, const UnauthorizedFailure('session expired')));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } on Exception catch (error) {
      handler.reject(_failure(request, ApiFailure.from(error)));
    }
  }

  static String? _bearer(RequestOptions options) {
    final header = options.headers['Authorization'];
    return header is String && header.startsWith('Bearer ') ? header.substring(7) : null;
  }

  static DioException _failure(RequestOptions options, ApiFailure failure) =>
      DioException(requestOptions: options, error: failure, message: failure.detail);
}
