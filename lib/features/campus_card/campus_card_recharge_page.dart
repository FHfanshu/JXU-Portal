import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/wechat/wechat_launcher.dart';

class CampusCardRechargePage extends StatefulWidget {
  const CampusCardRechargePage({super.key});

  static Uri get rechargeHomeUri => AppConfig.xiaofubaoRechargeUri;

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

    try {
      AppLogger.instance.info('校园卡充值：尝试原生 Intent 打开微信 H5 充值页');
      final launched = await WeChatLauncher.openUrlInWeChat(
        CampusCardRechargePage.rechargeHomeUri.toString(),
      );
      AppLogger.instance.info('校园卡充值：native intent launched=$launched');

      if (launched) {
        if (!mounted) return;
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.maybeOf(context);
        await navigator.maybePop();
        messenger?.showSnackBar(
          const SnackBar(content: Text('已跳转到微信，请在微信中完成充值')),
        );
        return;
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
                Text('请到微信「嘉兴大学校园卡」服务号完成充值', style: textTheme.headlineSmall),
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
                    child: Text(_launching ? '正在打开微信...' : '打开微信充值'),
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
