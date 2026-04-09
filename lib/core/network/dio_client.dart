import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';
import 'cookie_interceptor.dart';
import 'network_settings.dart';
import 'proxy_mode.dart';

class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();
  static const defaultZhengfangBaseUrl = 'https://jwzx.zjxu.edu.cn/jwglxt';

  PersistCookieJar? _cookieJar;
  Dio? _dio;
  Future<void>? _initFuture;

  PersistCookieJar get cookieJar =>
      _cookieJar ?? (throw StateError('DioClient has not been initialized.'));

  Dio get dio =>
      _dio ?? (throw StateError('DioClient has not been initialized.'));

  Future<void> init() async {
    await ensureInitialized();
  }

  Future<void> ensureInitialized() async {
    final existing = _initFuture;
    if (existing != null) return existing;

    final future = _initialize();
    _initFuture = future;
    try {
      await future;
    } catch (_) {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize() async {
    if (_dio != null && _cookieJar != null) return;

    await NetworkSettings.instance.ensureInitialized();
    final cookieDir = await _resolveCookieDirectoryPath();
    _cookieJar = PersistCookieJar(
      storage: FileStorage(cookieDir),
      persistSession: true,
    );
    _dio = _createDio();
  }

  void applyProxyMode() {
    final client = _dio;
    if (client == null) return;
    _applyProxyMode(client);
  }

  void updateBaseUrl(String baseUrl) {
    final client = _dio;
    if (client == null || client.options.baseUrl == baseUrl) return;
    client.options.baseUrl = baseUrl;
    AppLogger.instance.debug('教务请求基础地址已更新为: $baseUrl');
  }

  void _applyProxyMode(Dio client) {
    applyProxyModeToDio(
      client,
      ignoreSystemProxy: NetworkSettings.instance.ignoreSystemProxy.value,
    );
  }

  Dio _createDio() {
    final jar = _cookieJar!;
    final client = Dio(
      BaseOptions(
        baseUrl: defaultZhengfangBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    client.interceptors.add(buildCookieInterceptor(jar));
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.instance.debug('→ ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          final code = response.statusCode;
          final uri = response.requestOptions.uri;
          if (code == 302 || code == 303) {
            final location = response.headers.value('location') ?? '';
            AppLogger.instance.info('← $code $uri → $location');
            if (location.contains('login_slogin') ||
                location.contains('kaptcha') ||
                location.contains('webvpn.zjxu.edu.cn/login')) {
              AppLogger.instance.info('检测到重定向到登录/验证码页面，可能未在校园网环境');
            }
          } else {
            AppLogger.instance.debug('← $code $uri');
          }
          handler.next(response);
        },
        onError: (error, handler) {
          final msg =
              '请求失败: ${error.type} - ${error.requestOptions.uri} - ${error.message}';
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout) {
            AppLogger.instance.debug(msg);
          } else {
            AppLogger.instance.error(msg);
          }
          handler.next(error);
        },
      ),
    );
    _applyProxyMode(client);
    return client;
  }

  Future<String> _resolveCookieDirectoryPath() async {
    final override = debugCookieDirectoryPathProvider;
    if (override != null) {
      return override();
    }

    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/.cookies/';
  }

  @visibleForTesting
  Future<String> Function()? debugCookieDirectoryPathProvider;

  @visibleForTesting
  void debugReset() {
    _cookieJar = null;
    _dio = null;
    _initFuture = null;
    debugCookieDirectoryPathProvider = null;
  }
}
