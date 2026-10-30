import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// What the fake server answers to one request.
class FakeReply {
  const FakeReply(this.status, [this.body]) : offline = false;

  /// The request never reaches the server (no connection).
  const FakeReply.offline() : status = 0, body = null, offline = true;

  final int status;
  final Object? body;
  final bool offline;
}

typedef FakeHandler = FutureOr<FakeReply> Function(RequestOptions request);

/// A scripted HTTP server plugged in as Dio's adapter.
///
/// Tests go through the real Dio stack (interceptors, status validation,
/// JSON decoding), only the socket is replaced. Unscripted routes answer 404
/// so a test that calls something unexpected fails loudly.
class FakeServer implements HttpClientAdapter {
  final _handlers = <String, FakeHandler>{};

  /// Every request that reached the server, in order.
  final requests = <RequestOptions>[];

  void on(String method, String path, FakeHandler handler) => _handlers['$method $path'] = handler;

  void reply(String method, String path, int status, [Object? body]) =>
      on(method, path, (_) => FakeReply(status, body));

  List<RequestOptions> calls(String method, String path) =>
      requests.where((r) => r.method == method && r.uri.path == path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = _handlers['${options.method} ${options.uri.path}'];
    final reply = handler == null
        ? FakeReply(404, {'message': 'No fake for ${options.method} ${options.uri.path}'})
        : await handler(options);
    if (reply.offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'fake server is offline');
    }
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The `Authorization` header a request went out with.
String? bearerOf(RequestOptions request) => request.headers['Authorization'] as String?;

/// Lets pending async work (microtasks, zero-delay futures) run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
