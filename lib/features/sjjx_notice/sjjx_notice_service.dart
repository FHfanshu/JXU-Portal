import 'dart:convert';

import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/auth/unified_auth.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import 'sjjx_notice_model.dart';

const _sjjxNoticeBaseUrl = 'http://sjjx.zjxu.edu.cn/sjjx/';
const _sjjxNoticeListUrl =
    'http://sjjx.zjxu.edu.cn/sjjx/morenews.aspx?NewsType=gonggao';

@visibleForTesting
bool looksLikeSjjxResponseNeedsUnifiedAuth(Response<List<int>> response) {
  final realUrl = response.realUri.toString();
  if (isUnifiedAuthLoginEntryUrl(realUrl)) {
    return true;
  }

  if (isZhengfangGatewayLoginUrl(realUrl)) {
    return true;
  }

  final statusCode = response.statusCode ?? 0;
  if (statusCode == 302 || statusCode == 303) {
    final location = response.headers.value('location') ?? '';
    if (location.isNotEmpty) {
      final resolved = response.requestOptions.uri.resolve(location).toString();
      if (isUnifiedAuthLoginEntryUrl(resolved)) {
        return true;
      }
      if (isZhengfangGatewayLoginUrl(resolved)) {
        return true;
      }
    }
  }

  final body = response.data;
  if (body == null || body.isEmpty) {
    return false;
  }

  final html = utf8.decode(body, allowMalformed: true);
  if (looksLikeSjjxNoticeListHtml(html)) {
    return false;
  }
  return looksLikeUnifiedAuthLoginHtml(html);
}

@visibleForTesting
bool looksLikeSjjxNoticeListHtml(String html) {
  if (html.trim().isEmpty) {
    return false;
  }

  final doc = html_parser.parse(html);
  if (doc.querySelectorAll('.List_R02').isNotEmpty) {
    return true;
  }

  final title = doc.querySelector('title')?.text.trim() ?? '';
  if (!title.contains('实践')) {
    return false;
  }

  return doc.querySelector('.List_R02_L a') != null;
}

@visibleForTesting
String decodeSjjxNoticeHtml(Response<List<int>> response) {
  final body = response.data;
  if (body == null || body.isEmpty) {
    return '';
  }

  final contentType = (response.headers.value(Headers.contentTypeHeader) ?? '')
      .toLowerCase();
  if (contentType.contains('utf-8')) {
    return utf8.decode(body, allowMalformed: true);
  }
  if (contentType.contains('gbk') ||
      contentType.contains('gb2312') ||
      contentType.contains('gb18030')) {
    return gbk.decode(body, allowMalformed: true);
  }

  final utf8Html = utf8.decode(body, allowMalformed: true);
  if (looksLikeUnifiedAuthLoginHtml(utf8Html)) {
    return utf8Html;
  }
  return gbk.decode(body, allowMalformed: true);
}

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

  List<SjjxNotice>? get cachedNotices => _cachedNotices;

  Future<List<SjjxNotice>> fetchAllNotices() async {
    try {
      AppLogger.instance.network(LogLevel.info, '开始加载实践通知列表');
      final resp = await _getWithWebVpnFallback(_sjjxNoticeListUrl);
      if (resp.data == null || resp.data!.isEmpty) {
        AppLogger.instance.network(LogLevel.warn, '实践通知列表响应为空');
        return [];
      }

      final html = decodeSjjxNoticeHtml(resp);
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

  Future<Response<List<int>>> _getWithWebVpnFallback(String url) async {
    ZhengfangAuth.instance.setMode(ZhengfangMode.webVpn);
    return _fetchViaWebVpn(url, allowRecovery: true);
  }

  Future<Response<List<int>>> _fetchViaWebVpn(
    String url, {
    required bool allowRecovery,
  }) async {
    final proxyUrl = ZhengfangAuth.instance.buildWebVpnProxyUrl(url);
    if (proxyUrl == url) {
      throw StateError('实践通知 WebVPN 代理地址未配置');
    }

    final response = await DioClient.instance.unifiedAuthDio.get<List<int>>(
      proxyUrl,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 1000,
      ),
    );
    if (looksLikeSjjxResponseNeedsUnifiedAuth(response)) {
      if (allowRecovery) {
        AppLogger.instance.network(
          LogLevel.warn,
          '实践通知 WebVPN 目标页仍要求认证，尝试恢复 WebVPN 网关会话: $url',
        );
        final recovered = await ZhengfangAuth.instance
            .ensureWebVpnGatewaySession(syncWebViewCookies: false);
        if (recovered == true) {
          return _fetchViaWebVpn(url, allowRecovery: false);
        }
      }
      AppLogger.instance.network(LogLevel.warn, '实践通知 WebVPN 会话不可用: $url');
      throw StateError('实践通知 WebVPN 会话不可用');
    }
    AppLogger.instance.network(LogLevel.info, '实践通知已通过 WebVPN 回退加载');
    return response;
  }
}
