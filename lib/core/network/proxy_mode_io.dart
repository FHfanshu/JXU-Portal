import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void applyProxyModeToDio(Dio dio, {required bool ignoreSystemProxy}) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      if (ignoreSystemProxy) {
        client.findProxy = (_) => 'DIRECT';
      }
      return client;
    },
  );
}
