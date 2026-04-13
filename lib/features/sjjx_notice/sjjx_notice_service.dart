/// Stub implementation for open source release.
/// Real sjjx notice service implementation is not included.

import 'package:flutter/foundation.dart';

import 'sjjx_notice_model.dart';

class SjjxNoticeService {
  SjjxNoticeService._();
  static final SjjxNoticeService instance = SjjxNoticeService._();

  List<SjjxNotice>? _cachedNotices;

  List<SjjxNotice>? get cachedNotices => _cachedNotices;

  Future<List<SjjxNotice>> fetchAllNotices() async {
    // Stub - not implemented in open source version
    return _cachedNotices ?? [];
  }
}

@visibleForTesting
List<SjjxNotice> parseSjjxNoticeListHtml(String html) {
  // Stub - not implemented
  return [];
}