import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/network/network_settings.dart';
import '../../core/network/proxy_mode.dart';
import 'notice_model.dart';

const _jwcNoticeBaseUrl = 'https://jwc.zjxu.edu.cn/';
const _jwcNoticeListUrl = 'https://jwc.zjxu.edu.cn/list.jsp';

@visibleForTesting
List<Notice> parseJwcNoticeListHtml(String html) {
  final doc = html_parser.parse(html);
  final listItems = doc.querySelectorAll('#ul1 > li');
  final notices = <Notice>[];

  for (final item in listItems) {
    final link = item.querySelector('a.a1') ?? item.querySelector('a');
    if (link == null) continue;

    final title = link.text.trim();
    final href = link.attributes['href']?.trim() ?? '';
    if (title.isEmpty || href.isEmpty) continue;

    final dateText = item.querySelector('span.fr')?.text.trim() ?? item.text;
    final dateMatch = RegExp(
      r'20\d{2}[-./]\d{1,2}[-./]\d{1,2}',
    ).firstMatch(dateText);
    final date = dateMatch?.group(0)?.replaceAll('/', '-').replaceAll('.', '-');

    notices.add(
      Notice(
        title: title,
        url: Uri.parse(_jwcNoticeBaseUrl).resolve(href).toString(),
        category: '通知公告',
        date: date,
      ),
    );
  }

  return notices;
}

int? _extractJwcNoticeTotalPages(String html) {
  final doc = html_parser.parse(html);
  final pagerText = doc.querySelector('.pb_sys_common')?.text ?? '';
  final ratioMatch = RegExp(r'\b\d+\s*/\s*(\d+)\b').firstMatch(pagerText);
  if (ratioMatch != null) {
    return int.tryParse(ratioMatch.group(1) ?? '');
  }

  final lastPageHref = doc.querySelector('.p_last a')?.attributes['href'] ?? '';
  final pageMatch = RegExp(r'[?&]PAGENUM=(\d+)').firstMatch(lastPageHref);
  return int.tryParse(pageMatch?.group(1) ?? '');
}

class NoticeService {
  NoticeService._();
  static final NoticeService instance = NoticeService._();

  List<Notice>? _cachedNotices;
  int? _cachedTotalPages;

  Dio? _noticeDio;

  List<Notice>? get cachedNotices => _cachedNotices;

  Future<List<Notice>> fetchNotices() async {
    try {
      _cachedTotalPages = null;
      final notices = await _fetchNoticePage(1);
      _cachedNotices = notices;
      return notices;
    } catch (_) {
      return _cachedNotices ?? [];
    }
  }

  Future<List<Notice>> fetchMoreNotices(int page) async {
    if (page < 1) return [];
    final totalPages = _cachedTotalPages;
    if (totalPages != null && page > totalPages) return [];

    try {
      return await _fetchNoticePage(page);
    } catch (_) {
      return [];
    }
  }

  Future<List<Notice>> _fetchNoticePage(int page) async {
    final url = _buildNoticePageUrl(page);
    final resp = await (await _ensureNoticeDio()).get<List<int>>(url);
    if (resp.data == null || resp.data!.isEmpty) return [];

    final html = utf8.decode(resp.data!, allowMalformed: true);
    _cachedTotalPages ??= _extractJwcNoticeTotalPages(html);
    return parseJwcNoticeListHtml(html);
  }

  String _buildNoticePageUrl(int page) {
    final queryParameters = <String, String>{
      'urltype': 'tree.TreeTempUrl',
      'wbtreeid': '1046',
    };
    if (page > 1) {
      final totalPages = _cachedTotalPages;
      if (totalPages != null && totalPages > 0) {
        queryParameters['totalpage'] = '$totalPages';
      }
      queryParameters['PAGENUM'] = '$page';
    }

    return Uri.parse(
      _jwcNoticeListUrl,
    ).replace(queryParameters: queryParameters).toString();
  }

  Dio _createNoticeDio() {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
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

  Future<Dio> _ensureNoticeDio() async {
    await NetworkSettings.instance.ensureInitialized();
    final existing = _noticeDio;
    if (existing != null) return existing;

    final created = _createNoticeDio();
    _noticeDio = created;
    return created;
  }
}
