import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/sjjx_notice/sjjx_notice_service.dart';

void main() {
  test('parses sjjx notice list html into notice items', () {
    const html = '''
<div class="List_R02">
  <div class="List_R02_L FL">
    <a href="shownews.aspx?ptype=js&newsno=1907" title="关于举办2026年嘉兴大学大学生数学建模竞赛校内选拔赛的通知" target="_blank">[学科竞赛]关于举办2026年嘉兴大学大学生数学建模竞赛校内选拔赛的通知</a>
  </div>
  <div class="List_R02_R FL">2026-04-09</div>
</div>
<div class="List_R02">
  <div class="List_R02_L FL">
    <a href="http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?ptype=lw&newsno=203" title="关于2026届毕业设计（论文）第二阶段工作的通知" target="_blank">[毕业设计]关于2026届毕业设计（论文）第二阶段工作的通知</a>
  </div>
  <div class="List_R02_R FL">2026/04/08</div>
</div>
''';

    final notices = parseSjjxNoticeListHtml(html);

    expect(notices, hasLength(2));
    expect(notices.first.title, '关于举办2026年嘉兴大学大学生数学建模竞赛校内选拔赛的通知');
    expect(
      notices.first.url,
      'http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?ptype=js&newsno=1907',
    );
    expect(notices.first.category, '学科竞赛');
    expect(notices.first.date, '2026-04-09');

    expect(notices.last.category, '毕业设计');
    expect(
      notices.last.url,
      'http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?ptype=lw&newsno=203',
    );
    expect(notices.last.date, '2026-04-08');
  });
}
