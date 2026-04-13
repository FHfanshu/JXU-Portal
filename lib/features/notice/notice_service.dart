/// Stub implementation for open source release.
/// Real notice service implementation is not included.

import 'package:flutter/foundation.dart';

import 'notice_model.dart';

class NoticeService {
  NoticeService._();
  static final NoticeService instance = NoticeService._();

  List<Notice>? _cachedNotices;

  List<Notice>? get cachedNotices => _cachedNotices;

  Future<List<Notice>> fetchNotices() async {
    // Stub - not implemented in open source version
    return _cachedNotices ?? [];
  }

  Future<List<Notice>> fetchMoreNotices(int page) async {
    // Stub - not implemented in open source version
    return [];
  }
}

@visibleForTesting
List<Notice> parseJwcNoticeListHtml(String html) {
  // Stub - not implemented
  return [];
}