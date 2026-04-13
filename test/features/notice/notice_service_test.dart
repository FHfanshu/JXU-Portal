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
}
