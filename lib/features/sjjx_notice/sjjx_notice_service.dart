import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/network_settings.dart';
import '../../core/network/proxy_mode.dart';
import 'sjjx_notice_model.dart';

const _sjjxNoticeBaseUrl = 'http://sjjx.zjxu.edu.cn/sjjx/';
const _sjjxNoticeListUrl =
    'http://sjjx.zjxu.edu.cn/sjjx/morenews.aspx?NewsType=gonggao';

@visibleForTesting
List<SjjxNotice> parseSjjxNoticeListHtml(String html) {
  final doc = html_parser.parse(html);
  final items = doc.querySelectorAll('.List_R02');
  final notices = <SjjxNotice>[];

  for (final item in items) {
    final linkEl = item.querySelector('.List_R02_L a');
    final dateEl = item.querySelector('.List_R02_R');
    if (linkEl == null) continue;

    final rawTitle = linkEl.attributes['title']?.trim() ?? '';
    final href = linkEl.attributes['href']?.trim() ?? '';
    if (rawTitle.isEmpty || href.isEmpty) continue;

    final rawText = linkEl.text.trim();
    final catMatch = RegExp(r'^\[(.+?)\]').firstMatch(rawText);
    final category = catMatch?.group(1) ?? '其他';

    final dateText = dateEl?.text.trim() ?? '';
    final dateMatch = RegExp(
      r'20\d{2}[-/]\d{1,2}[-/]\d{1,2}',
    ).firstMatch(dateText);
    final date = dateMatch?.group(0)?.replaceAll('/', '-');

    notices.add(
      SjjxNotice(
        title: rawTitle,
        url: href.startsWith('http') ? href : '$_sjjxNoticeBaseUrl$href',
        category: category,
        date: date,
      ),
    );
  }

  return notices;
}

class SjjxNoticeService {
  SjjxNoticeService._();
  static final SjjxNoticeService instance = SjjxNoticeService._();

  List<SjjxNotice>? _cachedNotices;
  Dio? _dio;

  List<SjjxNotice>? get cachedNotices => _cachedNotices;

  Future<List<SjjxNotice>> fetchAllNotices() async {
    try {
      AppLogger.instance.network(LogLevel.info, '开始加载实践通知列表');
      final resp = await _getWithWebVpnFallback(_sjjxNoticeListUrl);
      if (resp.data == null || resp.data!.isEmpty) {
        AppLogger.instance.network(LogLevel.warn, '实践通知列表响应为空');
        return [];
      }

      final html = gbk.decode(resp.data!, allowMalformed: true);
      final notices = parseSjjxNoticeListHtml(html);
      if (notices.isEmpty) {
        final doc = html_parser.parse(html);
        final title = doc.querySelector('title')?.text.trim() ?? '';
        final itemCount = doc.querySelectorAll('.List_R02').length;
        AppLogger.instance.network(
          LogLevel.warn,
          '实践通知解析结果为空: title=$title, itemCount=$itemCount, bytes=${resp.data!.length}',
        );
      }
      AppLogger.instance.network(
        LogLevel.info,
        '实践通知列表加载成功，共 ${notices.length} 条',
      );

      _cachedNotices = notices;
      return notices;
    } catch (error, stackTrace) {
      final cachedNotices = _cachedNotices;
      if (cachedNotices != null) {
        AppLogger.instance.network(
          LogLevel.warn,
          '实践通知加载失败，回退缓存 ${cachedNotices.length} 条',
          error: error,
          stackTrace: stackTrace,
        );
        return cachedNotices;
      }
      AppLogger.instance.network(
        LogLevel.error,
        '实践通知加载失败',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Dio _createDio() {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
        responseType: ResponseType.bytes,
      ),
    );
    applyProxyModeToDio(
      client,
      ignoreSystemProxy: NetworkSettings.instance.ignoreSystemProxy.value,
    );
    return client;
  }

  Future<Dio> _ensureDio() async {
    await NetworkSettings.instance.ensureInitialized();
    final existing = _dio;
    if (existing != null) return existing;

    final created = _createDio();
    _dio = created;
    return created;
  }

  Future<Response<List<int>>> _getWithWebVpnFallback(String url) async {
    final directDio = await _ensureDio();
    try {
      return await directDio.get<List<int>>(url);
    } on DioException catch (error, stackTrace) {
      AppLogger.instance.network(
        LogLevel.warn,
        '实践通知直连失败，尝试通过 WebVPN 访问: $error',
      );
      final webVpnReady = await ZhengfangAuth.instance
          .validateWebVpnTargetSession(url);
      if (webVpnReady != true) {
        AppLogger.instance.network(
          LogLevel.warn,
          '实践通知 WebVPN 会话不可用，无法继续回退',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }

      try {
        final response = await DioClient.instance.unifiedAuthDio.get<List<int>>(
          ZhengfangAuth.instance.buildWebVpnProxyUrl(url),
          options: Options(responseType: ResponseType.bytes),
        );
        AppLogger.instance.network(LogLevel.info, '实践通知已通过 WebVPN 回退加载');
        return response;
      } on DioException catch (fallbackError, fallbackStackTrace) {
        AppLogger.instance.network(
          LogLevel.error,
          '实践通知 WebVPN 回退失败',
          error: fallbackError,
          stackTrace: fallbackStackTrace,
        );
        rethrow;
      }
    } catch (error, stackTrace) {
      AppLogger.instance.network(
        LogLevel.error,
        '实践通知请求异常',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
