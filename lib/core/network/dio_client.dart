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
  static const _zhengfangCookieFolderName = '.cookies';
  static const _unifiedAuthCookieFolderName = '.cookies_unified_auth';

  PersistCookieJar? _zhengfangCookieJar;
  PersistCookieJar? _unifiedAuthCookieJar;
  Dio? _zhengfangDio;
  Dio? _unifiedAuthDio;
  Future<void>? _initFuture;

  PersistCookieJar get cookieJar => zhengfangCookieJar;

  PersistCookieJar get zhengfangCookieJar =>
      _zhengfangCookieJar ??
      (throw StateError('DioClient has not been initialized.'));

  PersistCookieJar get unifiedAuthCookieJar =>
      _unifiedAuthCookieJar ??
      (throw StateError('DioClient has not been initialized.'));

  Dio get dio =>
      _zhengfangDio ??
      (throw StateError('DioClient has not been initialized.'));

  Dio get zhengfangDio => dio;

  Dio get unifiedAuthDio =>
      _unifiedAuthDio ??
      (throw StateError('DioClient has not been initialized.'));

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
    if (_zhengfangDio != null &&
        _unifiedAuthDio != null &&
        _zhengfangCookieJar != null &&
        _unifiedAuthCookieJar != null) {
      return;
    }

    await NetworkSettings.instance.ensureInitialized();
    final zhengfangCookieDir = await _resolveCookieDirectoryPath(
      _zhengfangCookieFolderName,
    );
    final unifiedAuthCookieDir = await _resolveCookieDirectoryPath(
      _unifiedAuthCookieFolderName,
    );
    _zhengfangCookieJar = PersistCookieJar(
      storage: FileStorage(zhengfangCookieDir),
      persistSession: true,
    );
    _unifiedAuthCookieJar = PersistCookieJar(
      storage: FileStorage(unifiedAuthCookieDir),
      persistSession: true,
    );
    _zhengfangDio = _createDio(
      jar: _zhengfangCookieJar!,
      baseUrl: defaultZhengfangBaseUrl,
    );
    _unifiedAuthDio = _createDio(
      jar: _unifiedAuthCookieJar!,
      baseUrl: 'https://newca.zjxu.edu.cn',
    );
  }

  void applyProxyMode() {
    final zhengfangClient = _zhengfangDio;
    if (zhengfangClient != null) {
      _applyProxyMode(zhengfangClient);
    }
    final unifiedAuthClient = _unifiedAuthDio;
    if (unifiedAuthClient != null) {
      _applyProxyMode(unifiedAuthClient);
    }
  }

  void updateBaseUrl(String baseUrl) {
    final client = _zhengfangDio;
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

  Dio _createDio({required PersistCookieJar jar, required String baseUrl}) {
    final client = Dio(
      BaseOptions(
        baseUrl: baseUrl,
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

  Future<String> _resolveCookieDirectoryPath(String folderName) async {
    final override = debugCookieDirectoryPathProvider;
    if (override != null) {
      return override(folderName);
    }

    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$folderName/';
  }

  @visibleForTesting
  Future<String> Function(String folderName)? debugCookieDirectoryPathProvider;

  @visibleForTesting
  void debugReset() {
    _zhengfangCookieJar = null;
    _unifiedAuthCookieJar = null;
    _zhengfangDio = null;
    _unifiedAuthDio = null;
    _initFuture = null;
    debugCookieDirectoryPathProvider = null;
  }
}
