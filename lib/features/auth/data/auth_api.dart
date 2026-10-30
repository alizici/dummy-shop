import 'package:dio/dio.dart';

import '../../../core/json/json_reader.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/session/session_tokens.dart';
import 'auth_user.dart';

/// DummyJSON auth endpoints.
///
/// [_public] has no auth interceptor (login, refresh); [_authorized] carries
/// the session token (`/auth/me`). Refresh must never go through the auth
/// interceptor, or a failing refresh would try to refresh itself.
class AuthApi {
  AuthApi({required Dio public, required Dio authorized}) : _public = public, _authorized = authorized;

  final Dio _public;
  final Dio _authorized;

  /// Access token lifetime asked from the server.
  static const sessionMinutes = 30;

  Future<(AuthUser, SessionTokens)> login({required String username, required String password}) async {
    try {
      final response = await _public.post<Object?>(
        '/auth/login',
        data: {'username': username, 'password': password, 'expiresInMins': sessionMinutes},
      );
      final json = JsonReader.root(response.data);
      return (AuthUser.fromJson(json), _tokens(json));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        throw InvalidCredentialsFailure('login rejected with HTTP $status');
      }
      rethrow;
    }
  }

  /// Throws [RefreshRejected] when the server refuses the refresh token
  /// (DummyJSON answers 403 for an invalid one). Other errors, 408 and 429
  /// included, are temporary and rethrown.
  Future<SessionTokens> refresh(String refreshToken) async {
    try {
      final response = await _public.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken, 'expiresInMins': sessionMinutes},
      );
      return _tokens(JsonReader.root(response.data));
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        throw RefreshRejected('HTTP $status');
      }
      rethrow;
    }
  }

  Future<AuthUser> me() async {
    final response = await _authorized.get<Object?>('/auth/me');
    return AuthUser.fromJson(JsonReader.root(response.data));
  }

  static SessionTokens _tokens(JsonReader json) =>
      SessionTokens.fromTokens(accessToken: json.string('accessToken'), refreshToken: json.string('refreshToken'));
}
