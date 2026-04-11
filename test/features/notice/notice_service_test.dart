import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/notice/notice_service.dart';

void main() {
  test('parses jwc notice list html into notice items', () {
    const html = '''
<ul id="ul1">
  <li class="clearfix">
    <span class="fr"><a href="content.jsp?urltype=news.NewsContentUrl&wbtreeid=1046&wbnewsid=10853" class="a2">[通知公告]</a>2026-04-08</span>
    <a href="content.jsp?urltype=news.NewsContentUrl&wbtreeid=1046&wbnewsid=10853" class="fl a1">关于开展继续教育专项检查工作的通知</a>
  </li>
  <li class="clearfix">
    <span class="fr"><a href="http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?ptype=js&newsno=1901" class="a2">[通知公告]</a>2026-03-30</span>
    <a href="http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?ptype=js&newsno=1901" class="fl a1">关于申报2026年嘉兴大学大学生科技竞赛项目的通知</a>
  </li>
</ul>
''';

    final notices = parseJwcNoticeListHtml(html);

    expect(notices, hasLength(2));
    expect(notices.first.title, '关于开展继续教育专项检查工作的通知');
    expect(
      notices.first.url,
      'https://jwc.zjxu.edu.cn/content.jsp?urltype=news.NewsContentUrl&wbtreeid=1046&wbnewsid=10853',
    );
    expect(notices.first.category, '通知公告');
    expect(notices.first.date, '2026-04-08');

    expect(
      notices.last.url,
      'http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?ptype=js&newsno=1901',
    );
    expect(notices.last.date, '2026-03-30');
  });

  test('detects unified auth login html response', () {
    const loginHtml = '''
<html>
  <head><title>统一身份认证平台</title></head>
  <body>
    <form id="fm1">
      <input name="execution" />
    </form>
  </body>
</html>
''';

    final response = Response<List<int>>(
      data: utf8.encode(loginHtml),
      requestOptions: RequestOptions(path: 'https://jwc.zjxu.edu.cn/list.jsp'),
    );

    expect(looksLikeNoticeResponseNeedsUnifiedAuth(response), isTrue);
  });

  test('does not treat normal notice page as unified auth login html', () {
    const pageHtml = '''
<html>
  <head><title>通知公告</title></head>
  <body>
    <ul id="ul1"><li><a class="a1" href="content.jsp?id=1">测试通知</a></li></ul>
  </body>
</html>
''';

    final response = Response<List<int>>(
      data: utf8.encode(pageHtml),
      requestOptions: RequestOptions(path: 'https://jwc.zjxu.edu.cn/list.jsp'),
    );

    expect(looksLikeNoticeResponseNeedsUnifiedAuth(response), isFalse);
  });
}
