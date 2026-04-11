import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/app_route_observer.dart';
import '../../core/auth/credential_store.dart';
import '../../shared/widgets/unified_auth_protected_webview_page.dart';
import 'campus_card_service.dart';
import 'ecard_service.dart';

class CampusCardPaymentPage extends StatefulWidget {
  const CampusCardPaymentPage({super.key});

  static Future<void> autoClickServiceHallPaymentCode(
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
  State<CampusCardPaymentPage> createState() => _CampusCardPaymentPageState();
}

class _CampusCardPaymentPageState extends State<CampusCardPaymentPage> {
  @override
  Widget build(BuildContext context) {
    return UnifiedAuthProtectedWebViewPage(
      title: '消费码',
      url: CampusCardService.paymentCodeServiceHallUrl,
      serviceUrl: CampusCardService.serviceHallCasServiceUrl,
      loginDescription: '统一认证登录后可直接进入建行消费码',
      onHomePressed: () => context.goNamed('home'),
      onLoadStop: CampusCardPaymentPage.autoClickServiceHallPaymentCode,
      appBarActions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CampusCardFallbackPaymentPage(),
              ),
            );
          },
          child: const Text('备用码'),
        ),
      ],
    );
  }
}

class CampusCardFallbackPaymentPage extends StatefulWidget {
  const CampusCardFallbackPaymentPage({super.key});

  @override
  State<CampusCardFallbackPaymentPage> createState() =>
      _CampusCardFallbackPaymentPageState();
}

class _CampusCardFallbackPaymentPageState
    extends State<CampusCardFallbackPaymentPage>
    with WidgetsBindingObserver, RouteAware {
  static const _fastPollInterval = Duration(seconds: 2);
  static const _slowPollInterval = Duration(seconds: 5);
  static const _fastPollAttempts = 15;
  static const _maxPollAttempts = 33;

  final _ecard = EcardService.instance;

  String? _qrCode;
  String? _accName;
  String? _accNum;
  String? _error;
  bool _loading = true;

  Timer? _pollTimer;
  String? _lastPaymentInfo;
  bool _showPaymentResult = false;
  bool _pollingStopped = false;
  int _pollAttempts = 0;
  int _pollSession = 0;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  PageRoute<dynamic>? _route;
  bool _isRouteForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic> || identical(route, _route)) {
      return;
    }

    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }

    _route = route;
    _isRouteForeground = route.isCurrent;
    appRouteObserver.subscribe(this, route);
    _resumePollingIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _cancelPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (_canPoll) {
      _resumePollingIfNeeded();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void didPush() {
    _isRouteForeground = true;
    _resumePollingIfNeeded();
  }

  @override
  void didPopNext() {
    _isRouteForeground = true;
    _resumePollingIfNeeded();
  }

  @override
  void didPushNext() {
    _isRouteForeground = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void didPop() {
    _isRouteForeground = false;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  bool get _canPoll =>
      _isRouteForeground && _appLifecycleState == AppLifecycleState.resumed;

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
      _pollingStopped = false;
    });

    _startPolling(result.qrCode!);
  }

  void _startPolling(String qrCode) {
    _cancelPolling(resetAttempts: true);
    _pollingStopped = false;
    _scheduleNextPoll(qrCode);
  }

  void _cancelPolling({bool resetAttempts = false}) {
    _pollSession += 1;
    _pollTimer?.cancel();
    _pollTimer = null;
    if (resetAttempts) {
      _pollAttempts = 0;
    }
  }

  void _resumePollingIfNeeded() {
    final qrCode = _qrCode;
    if (qrCode == null ||
        _loading ||
        _showPaymentResult ||
        _pollingStopped ||
        !_canPoll ||
        _pollTimer != null) {
      return;
    }

    _scheduleNextPoll(qrCode);
  }

  Duration _nextPollDelay() {
    return _pollAttempts < _fastPollAttempts
        ? _fastPollInterval
        : _slowPollInterval;
  }

  void _scheduleNextPoll(String qrCode) {
    if (!mounted || _pollingStopped || !_canPoll) return;

    if (_pollAttempts >= _maxPollAttempts) {
      _stopPollingWithHint();
      return;
    }

    final session = _pollSession;
    _pollTimer?.cancel();
    _pollTimer = Timer(_nextPollDelay(), () {
      unawaited(_pollOnce(qrCode, session));
    });
  }

  Future<void> _pollOnce(String qrCode, int session) async {
    if (!mounted || session != _pollSession || _pollingStopped || !_canPoll) {
      return;
    }

    _pollTimer = null;
    final info = await _ecard.getQRCodeInfo(qrCode);

    if (!mounted || session != _pollSession) return;

    _pollAttempts += 1;

    if (info.isUsed) {
      setState(() {
        _lastPaymentInfo = info.tradeAmt.isNotEmpty
            ? '¥${info.tradeAmt}'
            : '支付成功';
        _showPaymentResult = true;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || session != _pollSession) return;
      await _refreshQRCode();
      return;
    }

    _scheduleNextPoll(qrCode);
  }

  void _stopPollingWithHint() {
    _cancelPolling();
    if (!mounted || _pollingStopped) return;

    setState(() {
      _pollingStopped = true;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('状态轮询已暂停，请手动刷新消费码')));
  }

  Future<void> _refreshQRCode() async {
    if (_accNum == null) return;

    setState(() {
      _error = null;
      _loading = true;
      _showPaymentResult = false;
      _lastPaymentInfo = null;
      _pollingStopped = false;
    });

    _cancelPolling(resetAttempts: true);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('备用消费码')),
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
            if (_pollingStopped)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '状态轮询已暂停，请手动刷新后继续使用',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colorScheme.error),
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _refreshQRCode,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新消费码'),
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
