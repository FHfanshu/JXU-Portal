import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logging/app_logger.dart';

class CampusCardRechargePage extends StatefulWidget {
  const CampusCardRechargePage({super.key});

  static const weChatOAuthAppId = 'wx73282a5b4a6708c1';
  static const xiaofubaoThirdAppId = 'wx8fddf03d92fd6fa9';
  static final rechargeHomeUri = Uri.parse(
    'https://webapp.xiaofubao.com/card/card_home.shtml?platform=WECHAT_H5&schoolCode=10354&thirdAppid=$xiaofubaoThirdAppId',
  );

  static Uri buildWeChatBusinessWebViewUri(
    String h5Url, {
    required String appId,
  }) {
    return Uri(
      scheme: 'weixin',
      host: 'dl',
      path: '/businessWebview/link/',
      queryParameters: {'appid': appId, 'url': h5Url},
    );
  }

  @override
  State<CampusCardRechargePage> createState() => _CampusCardRechargePageState();
}

class _CampusCardRechargePageState extends State<CampusCardRechargePage> {
  bool _launching = false;
  bool _autoLaunchTriggered = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openInWeChat(autoTriggered: true);
      }
    });
  }

  Future<void> _openInWeChat({bool autoTriggered = false}) async {
    if (_launching) return;

    if (autoTriggered) {
      _autoLaunchTriggered = true;
    }

    setState(() {
      _launching = true;
      _statusMessage = autoTriggered ? '正在拉起微信充值页...' : null;
    });

    final launchCandidates = [
      (
        label: 'oauthAppId',
        uri: CampusCardRechargePage.buildWeChatBusinessWebViewUri(
          CampusCardRechargePage.rechargeHomeUri.toString(),
          appId: CampusCardRechargePage.weChatOAuthAppId,
        ),
      ),
      (
        label: 'thirdAppId',
        uri: CampusCardRechargePage.buildWeChatBusinessWebViewUri(
          CampusCardRechargePage.rechargeHomeUri.toString(),
          appId: CampusCardRechargePage.xiaofubaoThirdAppId,
        ),
      ),
    ];

    try {
      for (final candidate in launchCandidates) {
        try {
          AppLogger.instance.info(
            '校园卡充值：尝试通过微信 businessWebview 打开晓付宝首页 (${candidate.label})',
          );
          final launched = await launchUrl(
            candidate.uri,
            mode: LaunchMode.externalApplication,
          );
          AppLogger.instance.info(
            '校园卡充值：${candidate.label} launched=$launched',
          );
          if (!launched) continue;

          if (!mounted) return;
          final navigator = Navigator.of(context);
          final messenger = ScaffoldMessenger.maybeOf(context);
          await navigator.maybePop();
          messenger?.showSnackBar(
            const SnackBar(content: Text('已跳转到微信，请在微信中完成充值')),
          );
          return;
        } catch (error) {
          AppLogger.instance.error('校园卡充值：${candidate.label} 拉起失败 :: $error');
        }
      }

      if (!mounted) return;
      setState(() {
        _statusMessage = '没有成功拉起微信，请手动复制链接到微信中打开';
      });
    } finally {
      if (mounted) {
        setState(() => _launching = false);
      } else {
        _launching = false;
      }
    }
  }

  Future<void> _copyRechargeLink() async {
    await Clipboard.setData(
      ClipboardData(text: CampusCardRechargePage.rechargeHomeUri.toString()),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('充值链接已复制，请到微信中打开')));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('校园卡充值')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('充值需要在微信中完成', style: textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  '应用会优先直接拉起微信，进入晓付宝校园卡充值页。若没有自动跳转，可手动重试或复制链接到微信中打开。',
                  style: textTheme.bodyMedium,
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _launching ? null : _openInWeChat,
                    child: Text(_launching ? '正在打开微信...' : '打开微信继续充值'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _copyRechargeLink,
                    child: const Text('复制充值链接'),
                  ),
                ),
                if (!_autoLaunchTriggered) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => _openInWeChat(autoTriggered: true),
                      child: const Text('立即重试自动拉起'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
