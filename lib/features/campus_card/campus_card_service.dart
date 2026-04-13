/// Stub implementation for open source release.
/// Real campus card service implementation is not included.

import 'package:flutter/foundation.dart';

class CampusCardService {
  CampusCardService._();
  static final CampusCardService instance = CampusCardService._();

  double? _cachedBalance;
  DateTime? _lastUpdated;

  double? get cachedBalance => _cachedBalance;
  DateTime? get lastUpdated => _lastUpdated;

  // URL constants retained for UI reference
  static const statusPageUrl =
      'https://mobilehall.zjxu.edu.cn/webroot/decision/view/form?op=h5&viewlet=xxkj%252Fmobile%252Fykt.frm#/form';

  static const paymentCodeEntryUrl =
      'https://app.xiaoyuan.ccb.com/EMTSTATIC/DZK2026032101/index2026032101.html#/cardmentkey';

  void updateCachedBalance(double? balance) {
    if (balance == null) return;
    _cachedBalance = balance;
    _lastUpdated = DateTime.now();
  }

  Future<void> restoreBalance() async {
    // Stub - not implemented
  }

  double? parseBalanceFromPageText(String rawText) {
    // Stub - not implemented
    return null;
  }

  Future<double?> fetchBalance() async {
    // Stub - not implemented
    return _cachedBalance;
  }

  String formatBalance(double? balance) {
    if (balance == null) return '--';
    if (balance == balance.truncateToDouble()) {
      return balance.toStringAsFixed(0);
    }
    return balance
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @visibleForTesting
  void debugSetCachedBalance(double? balance, {DateTime? updatedAt}) {
    _cachedBalance = balance;
    _lastUpdated = updatedAt;
  }

  @visibleForTesting
  void debugReset() {
    _cachedBalance = null;
    _lastUpdated = null;
  }
}