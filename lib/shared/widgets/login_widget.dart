import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/credential_store.dart';
import '../../core/auth/zhengfang_auth.dart';
import 'login_shell.dart';

class LoginWidget extends StatefulWidget {
  const LoginWidget({
    super.key,
    required this.onLoginSuccess,
    this.showHeader = true,
    this.padding = const EdgeInsets.all(24),
  });

  final VoidCallback onLoginSuccess;
  final bool showHeader;
  final EdgeInsetsGeometry padding;

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  Uint8List? _captchaBytes;
  bool _loading = false;
  String? _error;

  ZhengfangMode _mode = ZhengfangMode.direct;
  bool _autoDetecting = true;
  bool _needCasAuth = false;
  bool _casAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _autoDetectNetwork();
  }

  Future<void> _autoDetectNetwork() async {
    if (!_autoDetecting) return;

    final directReachable = await ZhengfangAuth.checkDirectReachable();
    if (!mounted) return;

    if (directReachable) {
      setState(() {
        _mode = ZhengfangMode.direct;
        _autoDetecting = false;
      });
      ZhengfangAuth.instance.setMode(ZhengfangMode.direct);
      await _refreshCaptcha();
      return;
    }

    final webVpnReachable = await ZhengfangAuth.checkWebVpnReachable();
    if (!mounted) return;

    if (webVpnReachable) {
      if (ZhengfangAuth.instance.isLoggedIn &&
          ZhengfangAuth.instance.mode == ZhengfangMode.webVpn) {
        setState(() {
          _mode = ZhengfangMode.webVpn;
          _autoDetecting = false;
        });
        await _refreshCaptcha();
        return;
      }

      setState(() {
        _mode = ZhengfangMode.webVpn;
        _autoDetecting = false;
        _needCasAuth = true;
        _error = null;
        _captchaBytes = null;
      });
      ZhengfangAuth.instance.setMode(ZhengfangMode.webVpn);
      _promptUnifiedAuth();
      return;
    }

    setState(() {
      _autoDetecting = false;
      _captchaBytes = null;
      _error = '无法连接教务系统，请检查网络或在校园网环境下使用';
    });
  }

  Future<void> _promptUnifiedAuth() async {
    if (_casAuthenticating) return;
    _casAuthenticating = true;

    final loggedIn = await showUnifiedAuthLoginModal(
      context,
      title: '登录一卡通',
      description: '非校园网环境下需先完成一卡通认证',
      forceWebVpn: true,
      barrierDismissible: false,
    );

    _casAuthenticating = false;
    if (!mounted) return;

    if (loggedIn) {
      setState(() {
        _needCasAuth = false;
      });
      await _refreshCaptcha();
    } else {
      setState(() {
        _error = '需要完成一卡通认证才能继续';
      });
    }
  }

  Future<void> _loadSaved() async {
    final creds = await CredentialStore.instance.loadCredentials();
    if (creds != null) {
      _usernameCtrl.text = creds.$1;
      _passwordCtrl.text = creds.$2;
    }
  }

  Future<void> _refreshCaptcha() async {
    try {
      final bytes = await ZhengfangAuth.instance.fetchCaptcha();
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (mounted) {
        setState(() {
          _captchaBytes = bytes;
          _error = null;
        });
      }
    } on CaptchaException catch (e) {
      if (mounted) {
        final msg = e.message;
        if (_mode == ZhengfangMode.webVpn &&
            (msg.contains('已过期') || msg.contains('认证'))) {
          setState(() {
            _needCasAuth = true;
            _captchaBytes = null;
            _error = '一卡通认证已过期，请重新认证';
          });
          _promptUnifiedAuth();
        } else {
          setState(() {
            _captchaBytes = null;
            _error = msg;
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _captchaBytes = null;
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout) {
            _error = '无法连接教务系统，请检查网络';
          } else {
            _error = '网络错误：${e.message ?? "请稍后重试"}';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _captchaBytes = null;
          _error = '无法加载验证码，请重试';
        });
      }
    }
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final captcha = _captchaCtrl.text.trim();
    if (username.isEmpty || password.isEmpty || captcha.isEmpty) {
      setState(() => _error = '请填写学号、密码和验证码');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ZhengfangAuth.instance.login(
      username,
      password,
      captcha,
    );
    if (!mounted) return;
    switch (result) {
      case LoginSuccess():
        await CredentialStore.instance.saveCredentials(username, password);
        widget.onLoginSuccess();
      case LoginFailure(:final message):
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            const SizedBox(height: 24),
            Icon(
              _mode == ZhengfangMode.direct
                  ? Icons.school_outlined
                  : Icons.vpn_lock_outlined,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '登录教务系统',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
          ] else if (_mode == ZhengfangMode.webVpn && !_needCasAuth) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.vpn_lock_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '当前为 WebVPN 模式',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
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
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          if (!_autoDetecting && _needCasAuth)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.vpn_lock_outlined,
                    size: 48,
                    color: colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '非校园网环境',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '需先完成一卡通认证后再登录教务系统',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _promptUnifiedAuth,
                    icon: const Icon(Icons.login),
                    label: const Text('一卡通认证'),
                  ),
                ],
              ),
            ),

          if (!_autoDetecting && !_needCasAuth) ...[
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                hintText: '学号',
                prefixIcon: Icon(Icons.person_outline),
              ),
              keyboardType: TextInputType.number,
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
            _buildCaptchaRow(colorScheme),
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
              style: TextStyle(color: colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaptchaRow(ColorScheme colorScheme) {
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
            width: 120,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _captchaBytes != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Image.memory(
                        _captchaBytes!,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    )
                  : _error != null
                  ? Icon(Icons.refresh, color: colorScheme.error, size: 24)
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
