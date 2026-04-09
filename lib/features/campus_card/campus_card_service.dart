import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CampusCardService {
  CampusCardService._();

  static final CampusCardService instance = CampusCardService._();

  static const _storage = FlutterSecureStorage();
  static const _keyBalance = 'zjxu_campus_card_balance';

  double? _cachedBalance;
  DateTime? _lastUpdated;

  double? get cachedBalance => _cachedBalance;
  DateTime? get lastUpdated => _lastUpdated;

  static const statusPageUrl =
      'https://mobilehall.zjxu.edu.cn/webroot/decision/view/form?op=h5&viewlet=xxkj%252Fmobile%252Fykt.frm#/form';

  /// CAS service URL — fragment (#/form) 不能包含在 service 参数里，
  /// 否则 ticket 验证时 service 不匹配导致认证失败
  static const statusPageCasServiceUrl =
      'https://mobilehall.zjxu.edu.cn/webroot/decision/view/form?op=h5&viewlet=xxkj%252Fmobile%252Fykt.frm';

  static const paymentCodeEntryUrl =
      'https://app.xiaoyuan.ccb.com/EMTSTATIC/DZK2026032101/index2026032101.html#/cardmentkey';

  static const paymentCodeServiceHallUrl =
      'https://mobilehall.zjxu.edu.cn/mportal/start/index.html#/business/ydd/wfw/id=ED8D7B51A2422411E0532602010A9D8D';

  static const serviceHallCasServiceUrl =
      'https://newca.zjxu.edu.cn/casClient/login/ydd?services=business%2Fydd%2Fwfw';

  void updateCachedBalance(double? balance) {
    if (balance == null) return;
    _cachedBalance = balance;
    _lastUpdated = DateTime.now();
    _storage.write(key: _keyBalance, value: balance.toString());
  }

  Future<void> restoreBalance() async {
    final stored = await _storage.read(key: _keyBalance);
    if (stored != null) {
      _cachedBalance = double.tryParse(stored);
    }
  }

  double? parseBalanceFromPageText(String rawText) {
    final text = rawText
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u3000', ' ')
        .trim();
    if (text.isEmpty) return null;

    final lines = text
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line != '|')
        .toList();

    String normalize(String value) => value.replaceAll(RegExp(r'\s+'), '');

    double? parseAmount(String value) {
      final cleaned = value.replaceAll(',', '');
      final match = RegExp(
        r'[¥￥]?\s*([0-9]+(?:\.[0-9]+)?)\s*元?',
      ).firstMatch(cleaned);
      if (match == null) return null;
      return double.tryParse(match.group(1)!);
    }

    int labelIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      final normalized = normalize(lines[i]);
      if (normalized.contains('卡内余额')) {
        labelIndex = i;
        break;
      }
    }

    if (labelIndex >= 0) {
      final sameLineAmount = parseAmount(lines[labelIndex]);
      if (sameLineAmount != null) return sameLineAmount;

      for (int i = labelIndex - 1; i >= 0 && i >= labelIndex - 3; i--) {
        final amount = parseAmount(lines[i]);
        if (amount != null) return amount;
      }

      for (
        int i = labelIndex + 1;
        i < lines.length && i <= labelIndex + 3;
        i++
      ) {
        final amount = parseAmount(lines[i]);
        if (amount != null) return amount;
      }
    }

    final compact = normalize(text).replaceAll(',', '');
    final inlineMatch = RegExp(
      r'卡内余额[^0-9¥￥]{0,12}[¥￥]?([0-9]+(?:\.[0-9]+)?)',
    ).firstMatch(compact);
    if (inlineMatch != null) {
      return double.tryParse(inlineMatch.group(1)!);
    }

    return null;
  }

  Future<double?> fetchBalance() async {
    // The status page is JS-rendered (FineReport), so plain HTTP cannot
    // reliably extract the balance. Return cached value only; the real
    // balance is captured via WebView in CampusCardPage.
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
}
