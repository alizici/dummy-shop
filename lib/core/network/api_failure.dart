import 'package:dio/dio.dart';

import '../json/json_reader.dart';

/// Every way a backend call can fail, as the rest of the app sees it.
///
/// Repositories convert transport errors into one of these, so blocs and
/// widgets never deal with Dio, status codes or JSON paths.
sealed class ApiFailure implements Exception {
  const ApiFailure(this.detail);

  /// Developer-facing detail (logs, tests). Not shown to users as is.
  final String detail;

  /// Maps any error thrown below the repository layer.
  factory ApiFailure.from(Object error) => switch (error) {
    ApiFailure() => error,
    ResponseFormatException() => InvalidResponseFailure(error.toString()),
    DioException() => _fromDio(error),
    _ => UnexpectedFailure(error.toString()),
  };

  static ApiFailure _fromDio(DioException e) {
    final inner = e.error;
    if (inner is ApiFailure) return inner;
    if (inner is ResponseFormatException) return InvalidResponseFailure(inner.toString());
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(e.message ?? e.type.name);
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final message = _serverMessage(e.response?.data);
        if (status == 401) return UnauthorizedFailure(message ?? 'unauthorized');
        return ServerFailure(status, message);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return UnexpectedFailure(e.message ?? e.type.name);
    }
  }

  /// DummyJSON reports errors as `{"message": "..."}`.
  static String? _serverMessage(Object? body) {
    if (body is Map<String, Object?>) {
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }

  @override
  String toString() => '$runtimeType: $detail';
}

/// No connection, or the server didn't answer in time. Worth a retry.
final class NetworkFailure extends ApiFailure {
  const NetworkFailure(super.detail);
}

/// The session is missing or was rejected; the user has to sign in again.
final class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure(super.detail);
}

/// The server answered with an error status.
final class ServerFailure extends ApiFailure {
  const ServerFailure(this.statusCode, this.message) : super('HTTP $statusCode${message == null ? '' : ': $message'}');

  final int statusCode;

  /// The server's own message, when it sent one.
  final String? message;
}

/// The server answered, but not in the shape we rely on.
final class InvalidResponseFailure extends ApiFailure {
  const InvalidResponseFailure(super.detail);
}

/// Sign-in was refused: wrong username or password.
final class InvalidCredentialsFailure extends ApiFailure {
  const InvalidCredentialsFailure(super.detail);
}

final class UnexpectedFailure extends ApiFailure {
  const UnexpectedFailure(super.detail);
}

/// Runs a backend call and converts the exceptions it throws into an
/// [ApiFailure]. Programming errors ([Error]s) are left alone on purpose.
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on Exception catch (error) {
    throw ApiFailure.from(error);
  }
}
