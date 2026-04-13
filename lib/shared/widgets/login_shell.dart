import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/unified_auth.dart';
import 'login_widget.dart';
import 'unified_auth_login_widget.dart';

const _kInputRadius = BorderRadius.all(Radius.circular(18));
const double _kHorizontalMargin = 16;
const double _kFormCardRadius = 28;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground = theme.scaffoldBackgroundColor;
    final formSurface = isDark ? const Color(0xFF24191D) : Colors.white;
    final inputFill = isDark
        ? const Color(0xFF312429)
        : const Color(0xFFFFFBFA);
    final inputBorder = isDark
        ? BorderSide(color: Colors.white.withValues(alpha: 0.06))
        : const BorderSide(color: Color(0xFFE9E2DF));
    final focusBorder = isDark ? AppColors.primaryLight : AppColors.primary;
    final formShadow = isDark
        ? <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ];

    return Material(
      color: pageBackground,
      child: SafeArea(
        top: topSafeArea,
        bottom: false,
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: inputFill,
              border: OutlineInputBorder(
                borderRadius: _kInputRadius,
                borderSide: inputBorder,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: _kInputRadius,
                borderSide: inputBorder,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: _kInputRadius,
                borderSide: BorderSide(color: focusBorder, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: _kInputRadius,
                borderSide: BorderSide(color: Colors.red.shade300),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: _kInputRadius,
                borderSide: BorderSide(color: Colors.red.shade300, width: 1.6),
              ),
              prefixIconColor: isDark
                  ? Colors.white70
                  : const Color(0xFF8D837E),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 54,
                minHeight: 54,
              ),
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : const Color(0xFFAEA39D),
                fontSize: 16,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 17,
              ),
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 54),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topPadding = keyboardVisible ? 16.0 : 24.0;
              final bottomPadding = 28.0 + keyboardInset + 12;
              final minHeight =
                  constraints.maxHeight - topPadding - bottomPadding;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  _kHorizontalMargin,
                  topPadding,
                  _kHorizontalMargin,
                  bottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: minHeight > 0 ? minHeight : 0,
                  ),
                  child: Align(
                    alignment: keyboardVisible
                        ? Alignment.topCenter
                        : Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Container(
                        decoration: BoxDecoration(
                          color: formSurface,
                          borderRadius: BorderRadius.circular(_kFormCardRadius),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFF0E7E4),
                          ),
                          boxShadow: formShadow,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (badgeText != null || onClose != null)
                                Row(
                                  children: [
                                    if (badgeText != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: isDark ? 0.18 : 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          badgeText!,
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    const Spacer(),
                                    if (onClose != null)
                                      IconButton(
                                        onPressed: onClose,
                                        tooltip: '关闭',
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              colorScheme.surfaceContainerHigh,
                                          foregroundColor:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                        icon: const Icon(Icons.close, size: 20),
                                      ),
                                  ],
                                ),
                              if (badgeText != null || onClose != null)
                                const SizedBox(height: 20),
                              Text(
                                title,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 24),
                              child,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
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
  bool forceWebVpn = false,
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
          forceWebVpn: forceWebVpn,
          showHeader: false,
          padding: EdgeInsets.zero,
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

Future<bool> showWebVpnUnifiedAuthModal(
  BuildContext context, {
  String title = '登录一卡通',
  required String description,
  bool barrierDismissible = true,
}) {
  return showUnifiedAuthLoginModal(
    context,
    title: title,
    description: description,
    forceWebVpn: true,
    barrierDismissible: barrierDismissible,
  );
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
          padding: EdgeInsets.zero,
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
