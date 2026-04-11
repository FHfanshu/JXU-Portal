import 'package:flutter_test/flutter_test.dart';

import 'package:jiaxing_university_portal/features/sjjx_notice/sjjx_notice_list_page.dart';

void main() {
  test('sjjx detail should use webvpn protection', () {
    expect(
      shouldOpenSjjxNoticeViaWebVpn(
        'http://sjjx.zjxu.edu.cn/sjjx/shownews.aspx?id=1',
      ),
      isTrue,
    );
  });

  test('non campus detail should not use webvpn protection', () {
    expect(
      shouldOpenSjjxNoticeViaWebVpn('https://example.com/practice/1'),
      isFalse,
    );
  });
}
