import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../logging/app_logger.dart';
import '../network/proxy_mode.dart';
import 'update_model.dart';

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  static const latestReleaseUrl =
      'https://api.github.com/repos/FHfanshu/JXU-Portal/releases/latest';

  Dio? _dio;

  Future<AppRelease?> checkForUpdate() async {
    final release = await fetchLatestRelease();
    final currentVersion = await _loadCurrentVersion();
    if (release.isNewerThan(currentVersion)) {
      return release;
    }
    return null;
  }

  Future<AppRelease> fetchLatestRelease() async {
    final debugProvider = debugReleaseProvider;
    if (debugProvider != null) {
      return debugProvider();
    }

    final dio = _dio ??= _createDio();
    final response = await dio.get<Map<String, dynamic>>(latestReleaseUrl);
    final data = response.data;
    if (data == null) {
      throw const FormatException('GitHub release 响应为空。');
    }
    return AppRelease.fromGitHubJson(data);
  }

  Future<String> _loadCurrentVersion() async {
    final debugProvider = debugCurrentVersionProvider;
    if (debugProvider != null) {
      return debugProvider();
    }
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Dio _createDio() {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'JXU-Portal-App',
        },
      ),
    );
    // 更新检查始终独立遵循系统代理，不受教务直连开关影响。
    applyProxyModeToDio(client, ignoreSystemProxy: false);
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.instance.debug('→ 更新检查 ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.instance.debug('← 更新检查 ${response.statusCode}');
          handler.next(response);
        },
        onError: (error, handler) {
          AppLogger.instance.debug('更新检查失败: ${error.message}');
          handler.next(error);
        },
      ),
    );
    return client;
  }

  @visibleForTesting
  Future<AppRelease> Function()? debugReleaseProvider;

  @visibleForTesting
  Future<String> Function()? debugCurrentVersionProvider;

  @visibleForTesting
  void debugReset() {
    _dio = null;
    debugReleaseProvider = null;
    debugCurrentVersionProvider = null;
  }
}
