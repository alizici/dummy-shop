import 'package:dio/dio.dart';
import 'package:dummy_shop/app/failure_message.dart';
import 'package:dummy_shop/core/json/json_reader.dart';
import 'package:dummy_shop/core/network/api_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final request = RequestOptions(path: '/products');

  DioException http(int status, [Object? body]) => DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response<Object?>(requestOptions: request, statusCode: status, data: body),
  );

  group('ApiFailure.from', () {
    test('no connection and timeouts are network failures', () {
      expect(
        ApiFailure.from(DioException.connectionError(requestOptions: request, reason: 'x')),
        isA<NetworkFailure>(),
      );
      expect(
        ApiFailure.from(DioException.connectionTimeout(requestOptions: request, timeout: Duration.zero)),
        isA<NetworkFailure>(),
      );
      expect(
        ApiFailure.from(DioException.receiveTimeout(requestOptions: request, timeout: Duration.zero)),
        isA<NetworkFailure>(),
      );
    });

    test('401 means the session is not accepted', () {
      expect(ApiFailure.from(http(401)), isA<UnauthorizedFailure>());
    });

    test('other statuses keep the code and the server message', () {
      expect(
        ApiFailure.from(http(404, {'message': "Product with id '0' not found"})),
        isA<ServerFailure>()
            .having((f) => f.statusCode, 'statusCode', 404)
            .having((f) => f.message, 'message', "Product with id '0' not found"),
      );
      expect(ApiFailure.from(http(503, '<html>')), isA<ServerFailure>().having((f) => f.message, 'message', isNull));
    });

    test('a failure already decided below is kept as it is', () {
      const failure = UnauthorizedFailure('session expired');
      expect(ApiFailure.from(DioException(requestOptions: request, error: failure)), same(failure));
    });

    test('a malformed body is an invalid response', () {
      expect(
        ApiFailure.from(const ResponseFormatException(r'$.id', 'an integer', 'a string')),
        isA<InvalidResponseFailure>(),
      );
    });

    test('anything else is unexpected', () {
      expect(ApiFailure.from(Exception('boom')), isA<UnexpectedFailure>());
    });
  });

  group('guardApi', () {
    test('turns exceptions into failures', () {
      expect(guardApi<void>(() => throw http(500)), throwsA(isA<ServerFailure>()));
    });

    test('lets programming errors through', () {
      expect(guardApi<void>(() => throw StateError('bug')), throwsA(isA<StateError>()));
    });
  });

  group('failureMessage', () {
    test('shows the server message for client errors and a generic one for 5xx', () {
      expect(failureMessage(const ServerFailure(404, 'Not here')), 'Not here');
      expect(failureMessage(const ServerFailure(500, 'NullPointerException at ...')), isNot(contains('Null')));
    });

    test('has words for every failure', () {
      const failures = <ApiFailure>[
        NetworkFailure('x'),
        UnauthorizedFailure('x'),
        InvalidCredentialsFailure('x'),
        ServerFailure(400, null),
        InvalidResponseFailure('x'),
        UnexpectedFailure('x'),
      ];
      for (final failure in failures) {
        expect(failureMessage(failure), isNotEmpty, reason: '$failure');
      }
    });
  });
}
