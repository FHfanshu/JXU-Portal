import 'package:charset/charset.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

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
      final resp = await (await _ensureDio()).get<List<int>>(
        _sjjxNoticeListUrl,
      );
      if (resp.data == null || resp.data!.isEmpty) return [];

      final html = gbk.decode(resp.data!);
      final notices = parseSjjxNoticeListHtml(html);

      _cachedNotices = notices;
      return notices;
    } catch (_) {
      final cachedNotices = _cachedNotices;
      if (cachedNotices != null) {
        return cachedNotices;
      }
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
}
