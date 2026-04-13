import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../app/theme.dart';
import '../../core/logging/app_logger.dart';
import '../../core/shortcut/app_shortcut_service.dart';
import '../../shared/widgets/ship_card.dart';
import '../../shared/widgets/unified_auth_protected_webview_page.dart';
import 'campus_card_recharge_page.dart';
import 'campus_card_service.dart';

class CampusCardPage extends StatefulWidget {
  const CampusCardPage({super.key});

  @override
  State<CampusCardPage> createState() => _CampusCardPageState();
}

class _CampusCardPageState extends State<CampusCardPage> {
  static const _serviceHallHost = 'mobilehall.zjxu.edu.cn';
  static const _webVpnHost = 'webvpn.zjxu.edu.cn';
  static const _statusPathKeyword = '/decision/view/form';
  static const _statusViewletKeyword = 'ykt.frm';

  bool _capturedInCurrentDetailPage = false;
  bool _autoPopAfterCapture = false;
  bool _obscured = false;

  @override
  Widget build(BuildContext context) {
    final service = CampusCardService.instance;
    final balance = service.cachedBalance;
    final lastUpdated = service.lastUpdated;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    return Scaffold(
      appBar: AppBar(
        title: const Text('校园卡'),
        actions: [
          if (isAndroid)
            PopupMenuButton<_CampusCardMenuAction>(
              tooltip: '更多操作',
              onSelected: (action) {
                switch (action) {
                  case _CampusCardMenuAction.addShortcut:
                    _requestPaymentShortcut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_CampusCardMenuAction>(
                  value: _CampusCardMenuAction.addShortcut,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.add_to_home_screen_outlined),
                    title: Text('添加至桌面'),
                  ),
                ),
              ],
            ),
        ],
      ),
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
                  IconButton(
                    onPressed: () =>
                        _openCampusCardWebView(title: '刷新余额', autoPop: true),
                    tooltip: '刷新余额',
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.refresh,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => setState(() => _obscured = !_obscured),
                    tooltip: _obscured ? '显示余额' : '隐藏余额',
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
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
              if (balance == null)
                GestureDetector(
                  onTap: () =>
                      _openCampusCardWebView(title: '校园卡账单', autoPop: true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '点击查询余额',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              else
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
            subtitle: '请到微信「嘉兴大学校园卡」服务号完成充值',
            color: AppColors.success,
            onTap: _openRechargePage,
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

  Future<void> _openRechargePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CampusCardRechargePage()),
    );
  }

  Future<void> _requestPaymentShortcut() async {
    final created = await AppShortcutService.instance
        .requestCampusCardPaymentShortcut();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(created ? '已发起添加请求，请在系统提示中确认' : '当前设备暂不支持添加桌面快捷方式'),
      ),
    );
  }

  Future<void> _captureBalanceFromDetailPage(
    InAppWebViewController controller,
    String currentUrl,
  ) async {
    if (_capturedInCurrentDetailPage) return;

    final uri = Uri.tryParse(currentUrl);
    final path = uri?.path.toLowerCase();
    if (AppLogger.instance.config.value.webviewLifecycleEnabled) {
      AppLogger.instance.webview(LogLevel.debug, '校园卡 onLoadStop: $currentUrl');
    }
    if (uri == null || !_isCampusCardStatusPage(uri)) {
      if (AppLogger.instance.config.value.webviewLifecycleEnabled) {
        AppLogger.instance.webview(
          LogLevel.debug,
          '校园卡 跳过余额提取 (host=${uri?.host}, path=$path)',
        );
      }
      return;
    }

    final balance = await _extractBalanceWithRetry(controller);
    AppLogger.instance.webview(LogLevel.info, '校园卡余额提取结果: $balance');
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
        if (AppLogger.instance.config.value.webviewLifecycleEnabled) {
          AppLogger.instance.webview(
            LogLevel.debug,
            '校园卡 retry[$delayInMs ms] 文本长度=${text.length}',
          );
        }
        final balance = CampusCardService.instance.parseBalanceFromPageText(
          text,
        );
        if (balance != null) return balance;
      } catch (e) {
        if (AppLogger.instance.config.value.webviewLifecycleEnabled) {
          AppLogger.instance.webview(LogLevel.debug, '校园卡 JS 提取异常: $e');
        }
        continue;
      }
    }

    return null;
  }

  bool _isCampusCardStatusPage(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final viewlet = uri.queryParameters['viewlet']?.toLowerCase() ?? '';

    final isExpectedHost = host == _serviceHallHost || host == _webVpnHost;
    if (!isExpectedHost) return false;

    return path.contains(_statusPathKeyword) &&
        viewlet.contains(_statusViewletKeyword);
  }
}

// ── Campus Card Action ──────────────────────────────────────────────────────

enum _CampusCardMenuAction { addShortcut }

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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 172),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
