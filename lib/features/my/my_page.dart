import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth/unified_auth.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../shared/widgets/login_shell.dart';
import '../schedule/schedule_service.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _campusLoggedIn = false;
  bool _academicLoggedIn = false;
  bool _campusStatusChecking = false;
  bool _academicStatusChecking = false;
  bool _hasScheduleCache = false;
  DateTime? _scheduleUpdatedAt;
  int _statusRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    UnifiedAuthService.instance.addListener(_onAuthChanged);
    ZhengfangAuth.instance.addListener(_onAuthChanged);
    _refreshStatus();
  }

  @override
  void dispose() {
    UnifiedAuthService.instance.removeListener(_onAuthChanged);
    ZhengfangAuth.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    unawaited(_refreshStatus());
  }

  Future<void> _refreshStatus() async {
    final term = ScheduleService.instance.getCurrentTermContext();
    final snapshot = ScheduleService.instance.preferredSnapshot(
      termContext: term,
    );
    final refreshVersion = ++_statusRefreshVersion;
    final campusLoggedIn = UnifiedAuthService.instance.isLoggedIn;
    final academicLoggedIn = ZhengfangAuth.instance.isLoggedIn;

    setState(() {
      _campusLoggedIn = campusLoggedIn;
      _academicLoggedIn = academicLoggedIn;
      _campusStatusChecking = campusLoggedIn;
      _academicStatusChecking = academicLoggedIn;
      _hasScheduleCache = snapshot?.hasData ?? false;
      _scheduleUpdatedAt = snapshot?.lastUpdatedAt;
    });

    final campusValidationFuture = campusLoggedIn
        ? UnifiedAuthService.instance.validateSession()
        : Future<bool?>.value(false);
    final academicValidationFuture = academicLoggedIn
        ? ZhengfangAuth.instance.validateSession()
        : Future<bool?>.value(false);

    final campusValidation = await campusValidationFuture;
    final academicValidation = await academicValidationFuture;

    if (!mounted || refreshVersion != _statusRefreshVersion) return;

    setState(() {
      _campusLoggedIn =
          campusValidation ?? UnifiedAuthService.instance.isLoggedIn;
      _academicLoggedIn =
          academicValidation ?? ZhengfangAuth.instance.isLoggedIn;
      _campusStatusChecking = false;
      _academicStatusChecking = false;
      _hasScheduleCache = snapshot?.hasData ?? false;
      _scheduleUpdatedAt = snapshot?.lastUpdatedAt;
    });
  }

  Future<void> _openCampusCardAction() async {
    if (_campusLoggedIn) {
      await context.pushNamed('campus-card');
      if (!mounted) return;
      await _refreshStatus();
      return;
    }
    await showUnifiedAuthLoginModal(context);
    if (!mounted) return;
    await _refreshStatus();
  }

  Future<void> _loginAcademic() async {
    await showAcademicSystemLoginModal(context);
    if (!mounted) return;
    await _refreshStatus();
  }

  Future<void> _openAcademicH5() async {
    final h5Url = ZhengfangAuth.instance.buildPortalUrl(
      '/xtgl/index_initMenu.html',
      queryParameters: {
        'jsdm': 'xs',
        '_t': DateTime.now().millisecondsSinceEpoch,
      },
    );

    if (_academicLoggedIn) {
      await ZhengfangAuth.instance.syncCookiesToWebView();
    }
    if (!mounted) return;

    await context.pushNamed(
      'external-webview',
      extra: {'title': '教务系统', 'url': h5Url, 'enableLoginQuickFill': true},
    );
    if (!mounted) return;
    await _refreshStatus();
  }

  Future<void> _reloginCampus() async {
    await showUnifiedAuthLoginModal(context);
    if (!mounted) return;
    await _refreshStatus();
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '未缓存';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String _academicSubtitle() {
    if (_academicStatusChecking) {
      if (_hasScheduleCache) {
        return '正在校验教务状态 · 课表缓存 ${_formatTime(_scheduleUpdatedAt)}';
      }
      return '正在校验教务状态 · 课表未缓存';
    }
    if (_academicLoggedIn) {
      if (_hasScheduleCache) {
        return '已登录 · 课表更新 ${_formatTime(_scheduleUpdatedAt)}';
      }
      return '已登录 · 课表未缓存';
    }
    if (_hasScheduleCache) {
      return '未登录 · 课表缓存 ${_formatTime(_scheduleUpdatedAt)}';
    }
    return '未登录 · 课表未缓存';
  }

  String _campusSubtitle() {
    if (_campusStatusChecking) {
      return '正在校验统一认证状态';
    }
    return _campusLoggedIn ? '已登录' : '未登录';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_circle_outlined,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '账户中心',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '管理统一认证（含一卡通）、教务登录状态',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AccountStatusCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: AppColors.primary,
            title: '统一认证（含一卡通）',
            subtitle: _campusSubtitle(),
            primaryActionLabel: '登录',
            onPrimaryAction: _campusLoggedIn
                ? _reloginCampus
                : _openCampusCardAction,
            secondaryActionLabel: null,
            onSecondaryAction: null,
          ),
          const SizedBox(height: 12),
          _AccountStatusCard(
            icon: Icons.school_outlined,
            iconColor: AppColors.info,
            title: '教务系统',
            subtitle: _academicSubtitle(),
            primaryActionLabel: '登录',
            onPrimaryAction: _loginAcademic,
            secondaryActionLabel: '进入教务系统',
            onSecondaryAction: _openAcademicH5,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () async {
              await context.pushNamed('settings');
              if (!mounted) return;
              await _refreshStatus();
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? cs.surfaceContainerLowest : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? cs.outline.withValues(alpha: 0.3)
                      : cs.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '设置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '主题、学期、网络与调试选项',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountStatusCard extends StatelessWidget {
  const _AccountStatusCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerLowest : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? cs.outline.withValues(alpha: 0.3)
              : cs.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onPrimaryAction,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(primaryActionLabel),
              ),
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onSecondaryAction,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
