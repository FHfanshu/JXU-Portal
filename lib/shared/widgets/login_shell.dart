import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../core/auth/unified_auth.dart';
import 'login_widget.dart';
import 'unified_auth_login_widget.dart';

class LoginShell extends StatelessWidget {
  const LoginShell({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.badgeText,
    this.onClose,
    this.topSafeArea = true,
  });

  final String title;
  final String description;
  final Widget child;
  final String? badgeText;
  final VoidCallback? onClose;
  final bool topSafeArea;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: topSafeArea,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryDark,
                          AppColors.primary,
                          AppColors.primaryLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: -32,
                          bottom: -44,
                          child: Container(
                            width: 128,
                            height: 128,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -28,
                          top: -24,
                          child: Opacity(
                            opacity: isDark ? 0.12 : 0.16,
                            child: SvgPicture.asset(
                              'assets/header_texture.svg',
                              width: 150,
                              height: 150,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SvgPicture.asset(
                                      'assets/header_texture.svg',
                                    ),
                                  ),
                                  const Spacer(),
                                  if (onClose != null)
                                    IconButton(
                                      onPressed: onClose,
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                      ),
                                      tooltip: '关闭',
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (badgeText != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    badgeText!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Text(
                                title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scaffoldBackgroundColor: Colors.transparent,
                      cardColor: cs.surfaceContainerLowest,
                    ),
                    child: child,
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

Future<bool> showUnifiedAuthLoginModal(
  BuildContext context, {
  String title = '登录统一认证',
  String description = '登录后可进入一卡通、服务大厅等服务',
  String serviceUrl = UnifiedAuthService.defaultServiceUrl,
  bool barrierDismissible = true,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: '关闭统一认证登录',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation0, secondaryAnimation0) {
      return LoginShell(
        title: title,
        description: description,
        badgeText: '统一认证',
        onClose: barrierDismissible
            ? () => Navigator.of(dialogContext, rootNavigator: true).pop(false)
            : null,
        child: UnifiedAuthLoginWidget(
          serviceUrl: serviceUrl,
          title: title,
          description: description,
          showHeader: false,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          onLoginSuccess: () =>
              Navigator.of(dialogContext, rootNavigator: true).pop(true),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result == true;
}

Future<bool> showAcademicSystemLoginModal(
  BuildContext context, {
  bool barrierDismissible = true,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: barrierDismissible,
    barrierLabel: '关闭教务系统登录',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation0, secondaryAnimation0) {
      return LoginShell(
        title: '登录教务系统',
        description: '登录后可查看课表、成绩与教务服务',
        badgeText: '教务系统',
        onClose: barrierDismissible
            ? () => Navigator.of(dialogContext, rootNavigator: true).pop(false)
            : null,
        child: LoginWidget(
          showHeader: false,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          onLoginSuccess: () =>
              Navigator.of(dialogContext, rootNavigator: true).pop(true),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
  return result == true;
}
