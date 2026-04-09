import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';

class EcardService {
  EcardService._();
  static final EcardService instance = EcardService._();

  static const _baseUrl = 'http://ecard.zjxu.edu.cn:8012';
  static const _secretKey = 'ok15we1@oid8x5afd@';

  String? _cachedAccNum;
  String? _cachedAccName;

  String? get cachedAccNum => _cachedAccNum;
  String? get cachedAccName => _cachedAccName;

  @visibleForTesting
  static String formatTime(DateTime now) {
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  @visibleForTesting
  static String md5Hash(String input) {
    final digest = MD5Digest();
    final data = Uint8List.fromList(utf8.encode(input));
    final output = Uint8List(digest.digestSize);
    digest.update(data, 0, data.length);
    digest.doFinal(output, 0);
    return output.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @visibleForTesting
  static String generateSign(List<String> values) {
    final joined = values.join('|');
    return md5Hash('$joined|$_secretKey');
  }

  static String tripleBase64Encode(String input) {
    var result = input;
    for (var i = 0; i < 3; i++) {
      result = base64Encode(utf8.encode(result));
    }
    return result;
  }

  static String tripleBase64Decode(String input) {
    var result = input;
    for (var i = 0; i < 3; i++) {
      result = utf8.decode(base64Decode(result));
    }
    return result;
  }

  Map<String, String> _buildParams(Map<String, String> signParams) {
    final time = formatTime(DateTime.now());
    final sortedKeys = signParams.keys.toList()..sort();
    final sortedValues = sortedKeys.map((k) => signParams[k]!).toList();
    sortedValues.add(time);
    final sign = generateSign(sortedValues);
    return {...signParams, 'Time': time, 'Sign': sign, 'ContentType': 'json'};
  }

  Future<String> _post(String path, Map<String, String> params) async {
    await DioClient.instance.ensureInitialized();
    final dio = DioClient.instance.dio;
    final response = await dio.post<String>(
      '$_baseUrl$path',
      data: params,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        responseType: ResponseType.plain,
        headers: {'Referer': '$_baseUrl/index.html', 'Origin': _baseUrl},
      ),
    );
    return response.data ?? '';
  }

  static String studentIdToAccNum(String studentId) {
    return studentId.replaceFirst(RegExp(r'^0+'), '');
  }

  Future<bool> queryAccAuth(String accNum) async {
    try {
      final params = _buildParams({'AccNum': accNum});
      final body = await _post('/QueryAccAuth.aspx', params);
      final json = _tryParseJson(body);
      if (json != null && json['Code'] == '1') {
        AppLogger.instance.info('ecard 认证成功');
        return true;
      }
      AppLogger.instance.info('ecard 认证失败: ${json?['Msg'] ?? body}');
      return false;
    } catch (e) {
      AppLogger.instance.error('ecard 认证异常: $e');
      return false;
    }
  }

  Future<String?> getAccInfo(String accNum) async {
    try {
      final params = _buildParams({'AccNum': accNum});
      final body = await _post('/QueryAccInfoH.aspx', params);
      final json = _tryParseJson(body);
      if (json != null && json['Code'] == '1') {
        final accName = json['AccName'] as String? ?? '';
        _cachedAccName = accName;
        return accName;
      }
      return null;
    } catch (e) {
      AppLogger.instance.error('ecard 账户信息查询异常: $e');
      return null;
    }
  }

  Future<String?> getQRCode(String accNum) async {
    try {
      final params = _buildParams({'AccNum': accNum});
      final body = await _post('/GetQRCode.aspx', params);
      final json = _tryParseJson(body);
      if (json != null && json['Code'] == '1') {
        final qrCode = json['QRCode'] as String? ?? '';
        if (qrCode.isNotEmpty) {
          AppLogger.instance.info('ecard 二维码获取成功');
          return qrCode;
        }
      }
      final msg = json?['Msg'] as String? ?? '未知错误';
      AppLogger.instance.info('ecard 二维码获取失败: $msg');
      return null;
    } catch (e) {
      AppLogger.instance.error('ecard 二维码获取异常: $e');
      return null;
    }
  }

  Future<QRCodeInfoResult> getQRCodeInfo(String qrCode) async {
    try {
      final params = _buildParams({'QRCode': qrCode});
      final body = await _post('/GetQRCodeInfo.aspx', params);
      final json = _tryParseJson(body);
      if (json != null) {
        AppLogger.instance.debug('ecard QR状态响应: $json');
        final code = json['Code'] as String? ?? '';
        final msg = json['Msg'] as String? ?? '';
        final tradeAmt = json['TradeAmt'] as String? ?? '';
        final tradeState = json['TradeState'] as String? ?? '';
        return QRCodeInfoResult(
          code: code,
          msg: msg,
          tradeAmt: tradeAmt,
          tradeState: tradeState,
        );
      }
      return const QRCodeInfoResult(code: '', msg: '解析失败');
    } catch (e) {
      AppLogger.instance.debug('ecard 二维码状态查询异常: $e');
      return QRCodeInfoResult(code: '', msg: e.toString());
    }
  }

  Future<QRCodeInitResult> initializeAndCreateQRCode(String studentId) async {
    final accNum = studentIdToAccNum(studentId);
    _cachedAccNum = accNum;

    final authOk = await queryAccAuth(accNum);
    if (!authOk) {
      return QRCodeInitResult(error: '校园卡认证失败');
    }

    await getAccInfo(accNum);

    final qrCode = await getQRCode(accNum);
    if (qrCode == null) {
      return QRCodeInitResult(error: '获取消费码失败');
    }

    return QRCodeInitResult(
      accNum: accNum,
      accName: _cachedAccName,
      qrCode: qrCode,
    );
  }

  void clearCache() {
    _cachedAccNum = null;
    _cachedAccName = null;
  }

  Map<String, dynamic>? _tryParseJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class QRCodeInitResult {
  const QRCodeInitResult({this.accNum, this.accName, this.qrCode, this.error});

  final String? accNum;
  final String? accName;
  final String? qrCode;
  final String? error;

  bool get isSuccess => error == null && qrCode != null;
}

class QRCodeInfoResult {
  const QRCodeInfoResult({
    required this.code,
    this.msg = '',
    this.tradeAmt = '',
    this.tradeState = '',
  });

  final String code;
  final String msg;
  final String tradeAmt;
  final String tradeState;

  bool get isUsed => code == '1' && tradeAmt.isNotEmpty;
  bool get isPending => !isUsed;
}
