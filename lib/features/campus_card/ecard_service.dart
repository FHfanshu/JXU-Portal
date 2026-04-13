/// Stub implementation for open source release.
/// Real ecard service implementation is not included.
/// 
/// This file provides type definitions and stub implementations
/// to allow the UI code to compile without the actual payment logic.

class EcardService {
  EcardService._();
  static final EcardService instance = EcardService._();

  String? _cachedAccNum;
  String? _cachedAccName;

  String? get cachedAccNum => _cachedAccNum;
  String? get cachedAccName => _cachedAccName;

  static String studentIdToAccNum(String studentId) {
    return studentId.replaceFirst(RegExp(r'^0+'), '');
  }

  Future<bool> queryAccAuth(String accNum) async {
    // Stub - not implemented
    return false;
  }

  Future<String?> getAccInfo(String accNum) async {
    // Stub - not implemented
    return null;
  }

  Future<String?> getQRCode(String accNum) async {
    // Stub - not implemented
    return null;
  }

  Future<QRCodeInfoResult> getQRCodeInfo(String qrCode) async {
    // Stub - not implemented
    return const QRCodeInfoResult(code: '', msg: 'Not implemented');
  }

  Future<QRCodeInitResult> initializeAndCreateQRCode(String studentId) async {
    // Stub - not implemented
    return QRCodeInitResult(error: 'Not implemented in open source version');
  }

  void clearCache() {
    _cachedAccNum = null;
    _cachedAccName = null;
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