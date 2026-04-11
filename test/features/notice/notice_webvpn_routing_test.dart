import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/notice/notice_list_page.dart';

void main() {
  test('jwc detail should use unified auth protection', () {
    expect(
      shouldOpenNoticeViaUnifiedAuth(
        'https://jwc.zjxu.edu.cn/info/1024/1234.htm',
      ),
      isTrue,
    );
    expect(
      shouldOpenNoticeViaWebVpn('https://jwc.zjxu.edu.cn/info/1024/1234.htm'),
      isFalse,
    );
  });

  test('sjjx detail should use webvpn protection', () {
    expect(
      shouldOpenNoticeViaWebVpn(
        'http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?ptype=js&newsno=1901',
      ),
      isTrue,
    );
  });

  test('external detail should not use webvpn protection', () {
    expect(shouldOpenNoticeViaWebVpn('https://example.com/news/1'), isFalse);
    expect(
      shouldOpenNoticeViaUnifiedAuth('https://example.com/news/1'),
      isFalse,
    );
  });
}
