import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/network/dio_client.dart';
import '../../core/network/network_settings.dart';
import '../../core/network/proxy_mode.dart';
import 'notice_model.dart';

class NoticeService {
  NoticeService._();
  static final NoticeService instance = NoticeService._();

  List<Notice>? _cachedNotices;

  /// Total pages on the news site (descending numbering).
  static const _totalPages = 233;

  /// 缓存的新闻 Dio 实例（避免每次创建新实例）
  Dio? _newsDio;

  List<Notice>? get cachedNotices => _cachedNotices;

  /// 获取通知列表（调课信息 + 第一页综合新闻）— used by home page ticker
  Future<List<Notice>> fetchNotices() async {
    try {
      final notices = <Notice>[];

      final classAdjustments = await _fetchClassAdjustments();
      notices.addAll(classAdjustments);

      final news = await _fetchNewsPage(1);
      notices.addAll(news);

      _cachedNotices = notices;
      return notices;
    } catch (e) {
      return _cachedNotices ?? [];
    }
  }

  /// 获取更多新闻（分页）— used by notice list page infinite scroll
  Future<List<Notice>> fetchMoreNews(int page) async {
    if (page < 1 || page > _totalPages) return [];
    try {
      return await _fetchNewsPage(page);
    } catch (e) {
      return [];
    }
  }

  Future<List<Notice>> _fetchClassAdjustments() async {
    try {
      await DioClient.instance.ensureInitialized();
      final resp = await DioClient.instance.dio.post<Map<String, dynamic>>(
        '/xtgl/index_cxDbsy.html',
        queryParameters: {'flag': '1'},
      );
      final items = resp.data?['items'] as List<dynamic>? ?? [];
      return items
          .cast<Map<String, dynamic>>()
          .map(Notice.fromClassAdjustment)
          .take(3)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Notice>> _fetchNewsPage(int page) async {
    final url = page == 1
        ? 'https://news.zjxu.edu.cn/zhxw.htm'
        : 'https://news.zjxu.edu.cn/zhxw/${_totalPages - page + 1}.htm';

    final resp = await (await _ensureNewsDio()).get<List<int>>(url);
    if (resp.data == null) return [];

    final html = utf8.decode(resp.data!, allowMalformed: true);
    final doc = html_parser.parse(html);

    final listItems = doc.querySelectorAll('ul li');
    final notices = <Notice>[];
    for (final li in listItems) {
      final a = li.querySelector('a');
      if (a == null) continue;

      final title = a.text.trim();
      final href = a.attributes['href'] ?? '';
      if (title.isEmpty || href.isEmpty) continue;
      if (!href.endsWith('.htm') || !href.contains('info/')) continue;

      final date = _extractNewsDate(li);

      final fullUrl = href.startsWith('http')
          ? href
          : 'https://news.zjxu.edu.cn/$href';
      notices.add(
        Notice(title: title, url: fullUrl, category: '新闻', date: date),
      );
    }
    return notices;
  }

  String? _extractNewsDate(dynamic listItem) {
    final dateCandidates = [
      listItem.querySelector('.sp-list-time')?.text,
      listItem.querySelector('time')?.text,
      listItem.querySelector('p')?.text,
      listItem.querySelector('span')?.text,
    ];

    for (final candidate in dateCandidates) {
      final raw = (candidate ?? '').trim();
      if (raw.isEmpty) continue;

      final match = RegExp(r'20\d{2}[-./]\d{1,2}[-./]\d{1,2}').firstMatch(raw);
      if (match == null) continue;

      return match.group(0)!.replaceAll('/', '-').replaceAll('.', '-');
    }

    final allText = listItem.text?.toString() ?? '';
    final fallback = RegExp(
      r'20\d{2}[-./]\d{1,2}[-./]\d{1,2}',
    ).firstMatch(allText);
    if (fallback == null) return null;

    return fallback.group(0)!.replaceAll('/', '-').replaceAll('.', '-');
  }

  Dio _createNewsDio() {
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

  Future<Dio> _ensureNewsDio() async {
    await NetworkSettings.instance.ensureInitialized();
    final existing = _newsDio;
    if (existing != null) return existing;

    final created = _createNewsDio();
    _newsDio = created;
    return created;
  }
}
