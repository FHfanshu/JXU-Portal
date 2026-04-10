import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../logging/app_logger.dart';
import '../network/proxy_mode.dart';
import 'update_model.dart';

class UpdateService {
  UpdateService._();

  static final UpdateService instance = UpdateService._();

  static const giteeLatestReleaseUrl =
      'https://gitee.com/api/v5/repos/fhfanshu/JXU-Portal/releases/latest';
  static const githubLatestReleaseUrl =
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

    try {
      return await _fetchLatestGiteeRelease();
    } catch (error) {
      AppLogger.instance.info('Gitee 更新检查失败，回退 GitHub: $error');
    }

    return _fetchLatestGitHubRelease();
  }

  Future<AppRelease> _fetchLatestGiteeRelease() async {
    final debugProvider = debugGiteeReleaseProvider;
    if (debugProvider != null) {
      return debugProvider();
    }

    final dio = _dio ??= _createDio();
    final response = await dio.get<Map<String, dynamic>>(giteeLatestReleaseUrl);
    final data = response.data;
    if (data == null) {
      throw const FormatException('Gitee release 响应为空。');
    }
    return AppRelease.fromGiteeJson(
      data,
      owner: 'fhfanshu',
      repo: 'JXU-Portal',
    );
  }

  Future<AppRelease> _fetchLatestGitHubRelease() async {
    final debugProvider = debugGitHubReleaseProvider;
    if (debugProvider != null) {
      return debugProvider();
    }

    final dio = _dio ??= _createDio();
    final response = await dio.get<Map<String, dynamic>>(
      githubLatestReleaseUrl,
    );
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
          'Accept': 'application/json',
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
  Future<AppRelease> Function()? debugGiteeReleaseProvider;

  @visibleForTesting
  Future<AppRelease> Function()? debugGitHubReleaseProvider;

  @visibleForTesting
  Future<String> Function()? debugCurrentVersionProvider;

  @visibleForTesting
  void debugReset() {
    _dio = null;
    debugReleaseProvider = null;
    debugGiteeReleaseProvider = null;
    debugGitHubReleaseProvider = null;
    debugCurrentVersionProvider = null;
  }
}
