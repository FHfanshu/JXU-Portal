import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef RequestHandler = Future<ResponseBody> Function(RequestOptions options);

class MockHttpClientAdapter implements HttpClientAdapter {
  MockHttpClientAdapter({Map<String, RequestHandler>? handlers})
    : _handlers = handlers ?? <String, RequestHandler>{};

  final Map<String, RequestHandler> _handlers;
  final List<String> requestLog = <String>[];

  void register(String method, String path, RequestHandler handler) {
    _handlers[_key(method, path)] = handler;
  }

  void registerJson(
    String method,
    String path,
    Object? data, {
    int statusCode = 200,
    Map<String, List<String>> headers = const <String, List<String>>{},
  }) {
    register(method, path, (_) async {
      return ResponseBody.fromString(
        jsonEncode(data),
        statusCode,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
          ...headers,
        },
      );
    });
  }

  void registerText(
    String method,
    String path,
    String body, {
    int statusCode = 200,
    Map<String, List<String>> headers = const <String, List<String>>{},
  }) {
    register(method, path, (_) async {
      return ResponseBody.fromString(body, statusCode, headers: headers);
    });
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = _key(options.method, options.uri.path);
    requestLog.add('${options.method} ${options.uri.path}');
    final handler = _handlers[key];
    if (handler == null) {
      throw UnsupportedError(
        'Unhandled request: ${options.method} ${options.uri}',
      );
    }
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static String _key(String method, String path) =>
      '${method.toUpperCase()} $path';
}
