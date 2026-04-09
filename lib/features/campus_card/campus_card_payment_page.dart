import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/auth/credential_store.dart';
import '../../shared/widgets/unified_auth_protected_webview_page.dart';
import 'campus_card_service.dart';
import 'ecard_service.dart';

class CampusCardPaymentPage extends StatefulWidget {
  const CampusCardPaymentPage({super.key});

  @override
  State<CampusCardPaymentPage> createState() => _CampusCardPaymentPageState();
}

class _CampusCardPaymentPageState extends State<CampusCardPaymentPage> {
  final _ecard = EcardService.instance;

  bool _useWebView = false;

  String? _qrCode;
  String? _accName;
  String? _accNum;
  String? _error;
  bool _loading = true;

  Timer? _pollTimer;
  String? _lastPaymentInfo;
  bool _showPaymentResult = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final creds = await CredentialStore.instance.loadUnifiedAuthCredentials();
    if (creds == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '请先登录统一认证';
      });
      return;
    }

    final studentId = creds.$1;
    final result = await _ecard.initializeAndCreateQRCode(studentId);

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _loading = false;
        _error = result.error ?? '获取消费码失败';
      });
      return;
    }

    setState(() {
      _loading = false;
      _qrCode = result.qrCode;
      _accName = result.accName;
      _accNum = result.accNum;
    });

    _startPolling(result.qrCode!);
  }

  void _startPolling(String qrCode) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final info = await _ecard.getQRCodeInfo(qrCode);
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (info.isUsed) {
        timer.cancel();
        setState(() {
          _lastPaymentInfo = info.tradeAmt.isNotEmpty
              ? '¥${info.tradeAmt}'
              : '支付成功';
          _showPaymentResult = true;
        });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        _refreshQRCode();
      }
    });
  }

  Future<void> _refreshQRCode() async {
    if (_accNum == null) return;

    setState(() {
      _loading = true;
      _showPaymentResult = false;
      _lastPaymentInfo = null;
    });

    _pollTimer?.cancel();

    final qrCode = await _ecard.getQRCode(_accNum!);

    if (!mounted) return;

    if (qrCode == null) {
      setState(() {
        _loading = false;
        _error = '刷新消费码失败';
      });
      return;
    }

    setState(() {
      _loading = false;
      _qrCode = qrCode;
    });

    _startPolling(qrCode);
  }

  static Future<void> _autoClick(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    if (!currentUrl.contains('/business/ydd/wfw')) return;
    await controller.evaluateJavascript(
      source: '''
      (function() {
        var attempts = 0;
        var interval = setInterval(function() {
          if (++attempts > 20) { clearInterval(interval); return; }
          var items = document.querySelectorAll('#wfwbd .fk-list');
          if (!items.length) return;
          clearInterval(interval);
          for (var i = 0; i < items.length; i++) {
            var t = items[i].querySelector('.fk-text');
            if (t && t.innerText.trim() === '\u6d88\u8d39\u7801') {
              items[i].click();
              return;
            }
          }
        }, 300);
      })();
    ''',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useWebView) {
      return UnifiedAuthProtectedWebViewPage(
        title: '消费码',
        url: CampusCardService.paymentCodeServiceHallUrl,
        serviceUrl: CampusCardService.serviceHallCasServiceUrl,
        loginDescription: '统一认证登录后可直接进入消费码服务',
        onLoadStop: _autoClick,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('消费码')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(colorScheme)
          : _buildContent(colorScheme),
    );
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.error, fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _error = null;
                  _loading = true;
                });
                _ecard.clearCache();
                _initialize();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_accName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_accName!, style: const TextStyle(fontSize: 18)),
              ),
            if (_accNum != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Text(
                  '卡号: $_accNum',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            _buildQRCodeCard(colorScheme),
            const SizedBox(height: 16),
            Text(
              '请将二维码对准扫码设备',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _refreshQRCode,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新消费码'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                _pollTimer?.cancel();
                setState(() => _useWebView = true);
              },
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('切换到建行消费码'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQRCodeCard(ColorScheme colorScheme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showPaymentResult
              ? _buildPaymentResult(colorScheme)
              : _buildQRCode(colorScheme),
        ),
      ),
    );
  }

  Widget _buildQRCode(ColorScheme colorScheme) {
    if (_qrCode == null) return const SizedBox.shrink();

    final qrData = _qrCode!.contains(',')
        ? _qrCode!.split(',').first
        : _qrCode!;

    return Column(
      key: const ValueKey('qrcode'),
      mainAxisSize: MainAxisSize.min,
      children: [
        QrImageView(
          data: qrData,
          version: QrVersions.auto,
          size: 260,
          backgroundColor: Colors.white,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: colorScheme.primary,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentResult(ColorScheme colorScheme) {
    return SizedBox(
      key: const ValueKey('payment'),
      height: 260,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              _lastPaymentInfo ?? '支付成功',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
