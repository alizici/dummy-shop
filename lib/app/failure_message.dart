import '../core/network/api_failure.dart';

/// The one place that turns failures into words for the user.
/// The switch is exhaustive: a new failure type won't compile until it has a
/// message here.
String failureMessage(ApiFailure failure) => switch (failure) {
  NetworkFailure() => 'No connection. Check your internet and try again.',
  UnauthorizedFailure() => 'Your session has expired. Please sign in again.',
  InvalidCredentialsFailure() => 'Wrong username or password.',
  ServerFailure(:final statusCode) when statusCode >= 500 => 'The server is having trouble. Please try again later.',
  ServerFailure(:final message) => message ?? 'Something went wrong. Please try again.',
  InvalidResponseFailure() => 'We received an unexpected response. Please try again later.',
  UnexpectedFailure() => 'Something went wrong. Please try again.',
};
