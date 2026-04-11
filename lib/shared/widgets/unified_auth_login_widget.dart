import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/credential_store.dart';
import '../../core/auth/unified_auth.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';

enum UnifiedAuthMode { direct, webVpn }

typedef LoginCredentialLoader = Future<(String, String)?> Function();
typedef LoginCredentialSaver =
    Future<void> Function(String username, String password);
typedef LoginSessionPreflight = Future<bool> Function();
typedef LoginCaptchaLoader = Future<Uint8List> Function();
typedef LoginSubmitHandler =
    Future<String?> Function(String username, String password, String captcha);

class UnifiedAuthLoginWidget extends StatefulWidget {
  const UnifiedAuthLoginWidget({
    super.key,
    required this.onLoginSuccess,
    this.serviceUrl = UnifiedAuthService.defaultServiceUrl,
    this.title = '登录统一认证',
    this.description = '账号为校园一卡通号',
    this.loadSavedCredentials,
    this.saveCredentials,
    this.sessionPreflight,
    this.captchaLoader,
    this.loginHandler,
    this.forceWebVpn = false,
    this.showHeader = true,
    this.padding = const EdgeInsets.all(24),
  });

  final VoidCallback onLoginSuccess;
  final String serviceUrl;
  final String title;
  final String description;
  final LoginCredentialLoader? loadSavedCredentials;
  final LoginCredentialSaver? saveCredentials;
  final LoginSessionPreflight? sessionPreflight;
  final LoginCaptchaLoader? captchaLoader;
  final LoginSubmitHandler? loginHandler;
  final bool forceWebVpn;
  final bool showHeader;
  final EdgeInsetsGeometry padding;

  @override
  State<UnifiedAuthLoginWidget> createState() => _UnifiedAuthLoginWidgetState();
}

class _UnifiedAuthLoginWidgetState extends State<UnifiedAuthLoginWidget> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  Uint8List? _captchaBytes;
  bool _loading = false;
  String? _error;

  UnifiedAuthMode _mode = UnifiedAuthMode.direct;
  bool _autoDetecting = true;

  static const _proxyHint = '请求超时，请检查手机系统代理或 VPN 软件';

  @override
  void initState() {
    super.initState();
    _bootstrapLoginState();
  }

  Future<void> _bootstrapLoginState() async {
    await _loadSaved();

    if (widget.forceWebVpn) {
      await _prepareForcedWebVpnLogin();
      return;
    }

    if (UnifiedAuthService.instance.isLoggedIn) {
      if (mounted) widget.onLoginSuccess();
      return;
    }

    final hasActiveSession =
        await widget.sessionPreflight?.call() ??
        await UnifiedAuthService.instance.prepareLogin(
          serviceUrl: widget.serviceUrl,
        );
    if (!mounted) return;

    if (hasActiveSession) {
      widget.onLoginSuccess();
      return;
    }

    await _autoDetectNetwork();
  }

  Future<void> _prepareForcedWebVpnLogin() async {
    final webVpnReachable = await UnifiedAuthService.checkWebVpnReachable();
    if (!mounted) return;

    if (!webVpnReachable) {
      setState(() {
        _autoDetecting = false;
        _captchaBytes = null;
        _error = '无法连接 WebVPN，请检查网络连接';
      });
      return;
    }

    await _activateWebVpnMode();
  }

  Future<void> _activateWebVpnMode() async {
    if (!mounted) return;
    setState(() {
      _mode = UnifiedAuthMode.webVpn;
      _autoDetecting = false;
      _error = null;
      _captchaBytes = null;
    });
    ZhengfangAuth.instance.setMode(ZhengfangMode.webVpn);
    await _refreshCaptcha();
  }

  Future<void> _autoDetectNetwork() async {
    if (!_autoDetecting) return;

    final directReachable = await UnifiedAuthService.checkDirectReachable();
    if (!mounted) return;

    if (directReachable) {
      setState(() {
        _mode = UnifiedAuthMode.direct;
        _autoDetecting = false;
      });
      await _refreshCaptcha();
      return;
    }

    final webVpnReachable = await UnifiedAuthService.checkWebVpnReachable();
    if (!mounted) return;

    if (webVpnReachable) {
      await _activateWebVpnMode();
      return;
    }

    setState(() {
      _autoDetecting = false;
      _captchaBytes = null;
      _error = '无法连接统一认证，请检查网络连接';
    });
  }

  Future<void> _loadSaved() async {
    final credentials =
        await widget.loadSavedCredentials?.call() ??
        await CredentialStore.instance.loadUnifiedAuthCredentials();
    if (credentials != null) {
      _usernameCtrl.text = credentials.$1;
      _passwordCtrl.text = credentials.$2;
    }
  }

  Future<void> _refreshCaptcha() async {
    try {
      final bytes =
          await widget.captchaLoader?.call() ??
          (_mode == UnifiedAuthMode.webVpn
              ? await ZhengfangAuth.instance.fetchWebVpnCasCaptcha()
              : await UnifiedAuthService.instance.fetchCaptcha(
                  serviceUrl: widget.serviceUrl,
                ));
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _captchaBytes = bytes;
        _error = null;
      });
    } on WebVpnAlreadyAuthenticatedException {
      if (!mounted) return;
      AppLogger.instance.auth(LogLevel.info, 'WebVPN 已认证，跳过登录');
      widget.onLoginSuccess();
      return;
    } on UnifiedAuthCaptchaException catch (error) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        _error = error.message;
      });
    } on CaptchaException catch (error) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        _error = error.message;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          _error = _mode == UnifiedAuthMode.direct
              ? '$_proxyHint，然后重试统一认证'
              : '$_proxyHint，然后重试 WebVPN 登录';
        } else if (e.type == DioExceptionType.connectionError) {
          _error = _mode == UnifiedAuthMode.direct
              ? '无法连接统一认证，请检查网络或系统代理设置'
              : '无法连接 WebVPN，请检查网络或系统代理设置';
        } else {
          _error = '网络错误：${e.message ?? "请稍后重试"}';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        _error = '验证码加载失败，请点击重试';
      });
    }
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final captcha = _captchaCtrl.text.trim();
    if (username.isEmpty || password.isEmpty || captcha.isEmpty) {
      setState(() => _error = '请填写账号、密码和验证码');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.loginHandler != null) {
      final message = await widget.loginHandler!(username, password, captcha);
      if (!mounted) return;
      if (message == null) {
        await widget.saveCredentials?.call(username, password);
        widget.onLoginSuccess();
        return;
      }

      setState(() {
        _loading = false;
        _error = message;
      });
      _captchaCtrl.clear();
      _refreshCaptcha();
      return;
    }

    if (_mode == UnifiedAuthMode.webVpn) {
      final result = await ZhengfangAuth.instance.loginWebVpnCas(
        username,
        password,
        captcha,
      );
      if (!mounted) return;

      switch (result) {
        case WebVpnCasSuccess():
          await CredentialStore.instance.saveUnifiedAuthCredentials(
            username,
            password,
          );
          await ZhengfangAuth.instance.syncWebVpnCookiesToWebView();
          widget.onLoginSuccess();
        case WebVpnCasFailure(:final message):
          setState(() {
            _loading = false;
            _error = message;
          });
          _captchaCtrl.clear();
          _refreshCaptcha();
      }
      return;
    }

    final result = await UnifiedAuthService.instance.login(
      username,
      password,
      captcha,
      serviceUrl: widget.serviceUrl,
    );
    if (!mounted) return;

    switch (result) {
      case UnifiedAuthLoginSuccess():
        await (widget.saveCredentials?.call(username, password) ??
            CredentialStore.instance.saveUnifiedAuthCredentials(
              username,
              password,
            ));
        widget.onLoginSuccess();
      case UnifiedAuthLoginFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
        _captchaCtrl.clear();
        _refreshCaptcha();
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            const SizedBox(height: 24),
            Icon(
              _mode == UnifiedAuthMode.direct
                  ? Icons.account_balance_outlined
                  : Icons.vpn_lock_outlined,
              size: 64,
              color: cs.primary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
          ] else if (_mode == UnifiedAuthMode.webVpn) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.vpn_lock_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text(
                      '通过 WebVPN 连接',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_autoDetecting)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '正在检测网络环境...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          if (!_autoDetecting) ...[
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                hintText: _mode == UnifiedAuthMode.webVpn ? '一卡通账号' : '一卡通账号',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                hintText: '密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _buildCaptchaRow(cs),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '点击右侧验证码刷新',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : _login,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('登录'),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptchaRow(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _captchaCtrl,
            decoration: const InputDecoration(
              hintText: '验证码',
              prefixIcon: Icon(Icons.shield_outlined),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _refreshCaptcha,
          child: Container(
            width: 140,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _captchaBytes != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Image.memory(
                        _captchaBytes!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    )
                  : _error != null
                  ? Icon(Icons.refresh, color: cs.error, size: 24)
                  : const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
