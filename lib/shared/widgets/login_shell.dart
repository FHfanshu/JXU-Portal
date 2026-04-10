import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme.dart';
import '../../core/auth/unified_auth.dart';
import 'login_widget.dart';
import 'unified_auth_login_widget.dart';

const _kInputRadius = BorderRadius.all(Radius.circular(12));

/// Unified horizontal margin for both banner card and form area.
const double _kHorizontalMargin = 16;

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

    final formBackground = isDark
        ? const Color(0xFF1A1214)
        : const Color(0xFFFAFAFA);
    final inputFill = isDark ? const Color(0xFF2D1F23) : Colors.white;
    final inputBorder = isDark
        ? BorderSide.none
        : BorderSide(color: Colors.grey.shade200, width: 0.8);
    final focusBorder = isDark ? AppColors.primaryLight : AppColors.primary;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: topSafeArea,
        bottom: false,
        child: Column(
          children: [
            // Banner card
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _kHorizontalMargin,
                12,
                _kHorizontalMargin,
                0,
              ),
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
                  borderRadius: BorderRadius.circular(16),
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
                        opacity: 0.08,
                        child: SvgPicture.asset(
                          'assets/header_texture.svg',
                          width: 150,
                          height: 150,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: SvgPicture.asset(
                                  'assets/header_texture.svg',
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (badgeText != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
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
                              const Spacer(),
                              if (onClose != null)
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: IconButton(
                                    onPressed: onClose,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    tooltip: '关闭',
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Form area - vertically centered
            Expanded(
              child: Container(
                color: formBackground,
                child: Theme(
                  data: Theme.of(context).copyWith(
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
                        borderSide: BorderSide(color: focusBorder, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: _kInputRadius,
                        borderSide: BorderSide(color: Colors.red.shade300),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: _kInputRadius,
                        borderSide: BorderSide(
                          color: Colors.red.shade300,
                          width: 1.5,
                        ),
                      ),
                      prefixIconColor: Colors.grey[600],
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    filledButtonTheme: FilledButtonThemeData(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        _kHorizontalMargin,
                        20,
                        _kHorizontalMargin,
                        32,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
