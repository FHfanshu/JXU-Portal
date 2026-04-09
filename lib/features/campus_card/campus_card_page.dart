import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../app/theme.dart';
import '../../core/logging/app_logger.dart';
import '../../shared/widgets/ship_card.dart';
import '../../shared/widgets/unified_auth_protected_webview_page.dart';
import 'campus_card_service.dart';

class CampusCardPage extends StatefulWidget {
  const CampusCardPage({super.key});

  @override
  State<CampusCardPage> createState() => _CampusCardPageState();
}

class _CampusCardPageState extends State<CampusCardPage> {
  static const _serviceHallHost = 'mobilehall.zjxu.edu.cn';
  static const _statusPathKeyword = '/decision/view/form';

  bool _capturedInCurrentDetailPage = false;
  bool _autoPopAfterCapture = false;
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    if (CampusCardService.instance.cachedBalance == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openCampusCardWebView(title: '校园卡账单', autoPop: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = CampusCardService.instance;
    final balance = service.cachedBalance;
    final lastUpdated = service.lastUpdated;

    return Scaffold(
      appBar: AppBar(title: const Text('校园卡')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBalanceCard(context, balance, lastUpdated),
            const SizedBox(height: 16),
            _buildActionCards(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    double? balance,
    DateTime? lastUpdated,
  ) {
    final balanceText = balance != null ? balance.toStringAsFixed(2) : '--';
    final timeText = lastUpdated != null
        ? '上次更新 ${lastUpdated.hour.toString().padLeft(2, '0')}:${lastUpdated.minute.toString().padLeft(2, '0')}'
        : '暂未获取余额';

    return ShipCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.primary, AppColors.primaryDark],
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // Watermark
          Positioned(
            right: -16,
            top: -16,
            child: Icon(
              Icons.credit_card,
              size: 100,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.credit_card, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    '校园卡',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        _openCampusCardWebView(title: '刷新余额', autoPop: true),
                    child: Icon(
                      Icons.refresh,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _obscured = !_obscured),
                    child: Icon(
                      _obscured ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '¥ ',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    _obscured ? '****' : balanceText,
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CampusCardActionCard(
            icon: Icons.add_circle_outline,
            title: '充值',
            subtitle: '进入校园卡充值',
            color: AppColors.success,
            onTap: () => _openCampusCardWebView(title: '校园卡充值'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _CampusCardActionCard(
            icon: Icons.receipt_long_outlined,
            title: '账单',
            subtitle: '查看余额与明细',
            color: AppColors.info,
            onTap: () => _openCampusCardWebView(title: '校园卡账单'),
          ),
        ),
      ],
    );
  }

  Future<void> _openCampusCardWebView({
    required String title,
    bool autoPop = false,
  }) async {
    _capturedInCurrentDetailPage = false;
    _autoPopAfterCapture = autoPop;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnifiedAuthProtectedWebViewPage(
          title: title,
          url: CampusCardService.statusPageUrl,
          serviceUrl: CampusCardService.statusPageCasServiceUrl,
          loginDescription: '统一认证登录后可直接进入校园卡服务',
          onLoadStop: _captureBalanceFromDetailPage,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _captureBalanceFromDetailPage(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    if (_capturedInCurrentDetailPage) return;

    final uri = Uri.tryParse(currentUrl);
    final path = uri?.path.toLowerCase();
    AppLogger.instance.debug('校园卡 onLoadStop: $currentUrl');
    if (uri == null ||
        uri.host.toLowerCase() != _serviceHallHost ||
        path == null ||
        !path.contains(_statusPathKeyword)) {
      AppLogger.instance.debug('校园卡 跳过余额提取 (host=${uri?.host}, path=$path)');
      return;
    }

    final balance = await _extractBalanceWithRetry(controller);
    AppLogger.instance.info('校园卡余额提取结果: $balance');
    if (balance == null) return;

    CampusCardService.instance.updateCachedBalance(balance);
    _capturedInCurrentDetailPage = true;

    if (!mounted) return;
    setState(() {});
    if (_autoPopAfterCapture) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.maybeOf(context)?.maybePop();
      });
    }
  }

  Future<double?> _extractBalanceWithRetry(
    InAppWebViewController controller,
  ) async {
    const delaysInMs = [0, 700, 1400, 2200];

    for (final delayInMs in delaysInMs) {
      if (delayInMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: delayInMs));
      }

      try {
        final rawText = await controller.evaluateJavascript(
          source: '''
          (() => {
            const texts = [];
            const bodyText = document.body?.innerText;
            if (bodyText) texts.push(bodyText);
            const frames = document.querySelectorAll('iframe');
            for (const frame of frames) {
              try {
                const frameText = frame.contentDocument?.body?.innerText;
                if (frameText) texts.push(frameText);
              } catch (_) {}
            }
            return texts.join('\\n');
          })();
        ''',
        );

        final text = rawText is String ? rawText : '${rawText ?? ''}';
        AppLogger.instance.debug(
          '校园卡 retry[$delayInMs ms] 文本长度=${text.length}',
        );
        final balance = CampusCardService.instance.parseBalanceFromPageText(
          text,
        );
        if (balance != null) return balance;
      } catch (e) {
        AppLogger.instance.debug('校园卡 JS 提取异常: $e');
        continue;
      }
    }

    return null;
  }
}

// ── Campus Card Action ──────────────────────────────────────────────────────

class _CampusCardActionCard extends StatelessWidget {
  const _CampusCardActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ShipCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
