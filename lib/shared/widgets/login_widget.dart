import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/auth/credential_store.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';

/// Reusable login form widget. Calls [onLoginSuccess] when login succeeds.
/// 支持直连和 WebVPN 两种模式。
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

  // WebVPN 两步登录相关
  final _accountCtrl = TextEditingController();
  final _accountPasswordCtrl = TextEditingController();
  final _casCaptchaCtrl = TextEditingController();

  Uint8List? _captchaBytes;
  Uint8List? _casCaptchaBytes;
  bool _loading = false;
  String? _error;

  /// 当前连接模式
  ZhengfangMode _mode = ZhengfangMode.direct;

  /// WebVPN 一卡通认证是否完成
  bool _casAuthenticated = false;

  /// 是否正在进行自动检测
  bool _autoDetecting = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
    _autoDetectNetwork();
  }

  /// 自动检测网络环境并选择合适的登录模式
  Future<void> _autoDetectNetwork() async {
    if (_autoDetecting) return;
    _autoDetecting = true;

    try {
      AppLogger.instance.debug('正在自动检测网络环境...');
      final directReachable = await ZhengfangAuth.checkDirectReachable();

      if (!directReachable) {
        final webVpnReachable = await ZhengfangAuth.checkWebVpnReachable();
        if (webVpnReachable) {
          if (mounted) {
            setState(() {
              _error = '非校园网环境，将切换到 WebVPN 登录';
            });
          }
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _switchToWebVpn();
          }
          _autoDetecting = false;
          return;
        }

        if (mounted) {
          setState(() {
            _captchaBytes = null;
            _error = '无法连接教务系统，请检查网络或在校园网环境下使用';
          });
        }
        _autoDetecting = false;
        return;
      }

      if (mounted) {
        await _refreshCaptcha();
      }
    } catch (e) {
      AppLogger.instance.error('网络检测异常: $e');
    } finally {
      _autoDetecting = false;
    }
  }

  Future<void> _loadSaved() async {
    final creds = await CredentialStore.instance.loadCredentials();
    if (creds != null) {
      _usernameCtrl.text = creds.$1;
      _passwordCtrl.text = creds.$2;
    }
    final unifiedCreds = await CredentialStore.instance
        .loadUnifiedAuthCredentials();
    if (unifiedCreds != null) {
      _accountCtrl.text = unifiedCreds.$1;
      _accountPasswordCtrl.text = unifiedCreds.$2;
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
        if (_mode == ZhengfangMode.webVpn &&
            (e.message.contains('已过期') || e.message.contains('认证'))) {
          setState(() {
            _casAuthenticated = false;
            _captchaBytes = null;
            _error = '一卡通认证已过期，请重新认证';
          });
        } else {
          setState(() {
            _captchaBytes = null;
            _error = e.message;
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _captchaBytes = null;
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout) {
            _error = _mode == ZhengfangMode.direct
                ? '无法连接教务系统，请确保在校园网环境或已连接VPN'
                : '无法连接 WebVPN，请检查网络';
          } else {
            _error = '网络错误：${e.message ?? "请稍后重试"}';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _captchaBytes = null;
          _error = '无法加载验证码，请确保在校园网环境或已连接VPN后点击重试';
        });
      }
    }
  }

  /// 获取 WebVPN CAS 验证码
  Future<void> _refreshCasCaptcha() async {
    try {
      final bytes = await ZhengfangAuth.instance.fetchWebVpnCasCaptcha();
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (mounted) {
        setState(() {
          _casCaptchaBytes = bytes;
          _error = null;
        });
      }
    } on CaptchaException catch (e) {
      if (mounted) {
        setState(() {
          _casCaptchaBytes = null;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _casCaptchaBytes = null;
          _error = 'WebVPN 验证码加载失败，请重试';
        });
      }
    }
  }

  /// 切换到 WebVPN 模式
  void _switchToWebVpn() {
    ZhengfangAuth.instance.setMode(ZhengfangMode.webVpn);
    setState(() {
      _mode = ZhengfangMode.webVpn;
      _error = null;
      _captchaBytes = null;
      _captchaCtrl.clear();
      _casCaptchaBytes = null;
      _casCaptchaCtrl.clear();
    });
    _refreshCasCaptcha();
  }

  /// 切换到直连模式
  void _switchToDirect() {
    ZhengfangAuth.instance.setMode(ZhengfangMode.direct);
    setState(() {
      _mode = ZhengfangMode.direct;
      _casAuthenticated = false;
      _error = null;
      _captchaBytes = null;
      _captchaCtrl.clear();
      _casCaptchaBytes = null;
      _casCaptchaCtrl.clear();
    });
    _refreshCaptcha();
  }

  /// Step 1: WebVPN 一卡通认证 (含验证码)
  Future<void> _authenticateCas() async {
    final account = _accountCtrl.text.trim();
    final password = _accountPasswordCtrl.text;
    final captcha = _casCaptchaCtrl.text.trim();
    if (account.isEmpty || password.isEmpty || captcha.isEmpty) {
      setState(() => _error = '请填写一卡通账号、密码和验证码');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ZhengfangAuth.instance.loginWebVpnCas(
      account,
      password,
      captcha,
    );
    if (!mounted) return;

    switch (result) {
      case WebVpnCasSuccess():
        await CredentialStore.instance.saveUnifiedAuthCredentials(
          account,
          password,
        );
        setState(() {
          _casAuthenticated = true;
          _loading = false;
        });
        await _refreshCaptcha();
      case WebVpnCasFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
        _casCaptchaCtrl.clear();
        _refreshCasCaptcha();
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
    _accountCtrl.dispose();
    _accountPasswordCtrl.dispose();
    _casCaptchaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
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
              '登录正方教务系统',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_mode == ZhengfangMode.webVpn) ...[
              const SizedBox(height: 4),
              Text(
                'WebVPN 模式',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 32),
          ] else if (_mode == ZhengfangMode.webVpn) ...[
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '当前为 WebVPN 登录模式',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // ── 网络检测中 ──
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

          // ── 直连模式：标准登录表单 ──
          if (!_autoDetecting && _mode == ZhengfangMode.direct)
            ..._buildDirectLoginForm(colorScheme),

          // ── WebVPN 模式：两步登录 ──
          if (!_autoDetecting &&
              _mode == ZhengfangMode.webVpn &&
              !_casAuthenticated)
            ..._buildWebVpnCasForm(colorScheme),
          if (!_autoDetecting &&
              _mode == ZhengfangMode.webVpn &&
              _casAuthenticated)
            ..._buildWebVpnJwzxForm(colorScheme),

          // ── 错误信息 ──
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: colorScheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          // ── 非校园网提示 ──
          if (_mode == ZhengfangMode.direct &&
              _captchaBytes == null &&
              _error != null &&
              _error!.contains('校园网')) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _switchToWebVpn,
              icon: const Icon(Icons.vpn_lock, size: 18),
              label: const Text('切换到 WebVPN 登录'),
            ),
            const SizedBox(height: 4),
            Text(
              '非校园网环境请使用 WebVPN',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildDirectLoginForm(ColorScheme colorScheme) {
    return [
      TextField(
        controller: _usernameCtrl,
        decoration: const InputDecoration(
          labelText: '学号',
          prefixIcon: Icon(Icons.person_outline),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _passwordCtrl,
        decoration: const InputDecoration(
          labelText: '密码',
          prefixIcon: Icon(Icons.lock_outline),
          border: OutlineInputBorder(),
        ),
        obscureText: true,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _captchaCtrl,
              decoration: const InputDecoration(
                labelText: '验证码',
                prefixIcon: Icon(Icons.security),
                border: OutlineInputBorder(),
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
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _error != null && _captchaBytes == null
                      ? colorScheme.error
                      : colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _captchaBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.memory(_captchaBytes!, fit: BoxFit.fill),
                    )
                  : _error != null
                  ? Center(
                      child: Icon(
                        Icons.refresh,
                        color: colorScheme.error,
                        size: 28,
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _loading ? null : _login,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('登 录'),
      ),
      const SizedBox(height: 8),
      Text(
        '点击验证码图片可刷新',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    ];
  }

  /// Step 1: WebVPN 一卡通认证表单 (含验证码)
  List<Widget> _buildWebVpnCasForm(ColorScheme colorScheme) {
    return [
      _buildStepHeader('1', '一卡通认证', false),
      const SizedBox(height: 16),
      TextField(
        controller: _accountCtrl,
        decoration: const InputDecoration(
          labelText: '一卡通账号',
          prefixIcon: Icon(Icons.person_outline),
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _accountPasswordCtrl,
        decoration: const InputDecoration(
          labelText: '一卡通密码',
          prefixIcon: Icon(Icons.lock_outline),
          border: OutlineInputBorder(),
        ),
        obscureText: true,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _casCaptchaCtrl,
              decoration: const InputDecoration(
                labelText: '验证码',
                prefixIcon: Icon(Icons.security),
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _authenticateCas(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _refreshCasCaptcha,
            child: Container(
              width: 120,
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _error != null && _casCaptchaBytes == null
                      ? colorScheme.error
                      : colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _casCaptchaBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.memory(_casCaptchaBytes!, fit: BoxFit.fill),
                    )
                  : _error != null
                  ? Center(
                      child: Icon(
                        Icons.refresh,
                        color: colorScheme.error,
                        size: 28,
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _loading ? null : _authenticateCas,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('一卡通认证'),
      ),
      const SizedBox(height: 8),
      Text(
        '点击验证码图片可刷新',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _switchToDirect,
        icon: const Icon(Icons.swap_horiz, size: 16),
        label: const Text('切换到校园网直连'),
      ),
    ];
  }

  List<Widget> _buildWebVpnJwzxForm(ColorScheme colorScheme) {
    return [
      _buildStepHeader('1', '一卡通认证', true),
      const SizedBox(height: 16),
      _buildStepHeader('2', '教务系统登录', false),
      const SizedBox(height: 16),
      TextField(
        controller: _usernameCtrl,
        decoration: const InputDecoration(
          labelText: '学号',
          prefixIcon: Icon(Icons.badge_outlined),
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _passwordCtrl,
        decoration: const InputDecoration(
          labelText: '教务系统密码',
          prefixIcon: Icon(Icons.lock_outline),
          border: OutlineInputBorder(),
        ),
        obscureText: true,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _captchaCtrl,
              decoration: const InputDecoration(
                labelText: '验证码',
                prefixIcon: Icon(Icons.security),
                border: OutlineInputBorder(),
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
              height: 56,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _error != null && _captchaBytes == null
                      ? colorScheme.error
                      : colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: _captchaBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.memory(_captchaBytes!, fit: BoxFit.fill),
                    )
                  : _error != null
                  ? Center(
                      child: Icon(
                        Icons.refresh,
                        color: colorScheme.error,
                        size: 28,
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _loading ? null : _login,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('登 录'),
      ),
      const SizedBox(height: 8),
      Text(
        '点击验证码图片可刷新',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    ];
  }

  Widget _buildStepHeader(String number, String label, bool done) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done ? Colors.green : colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
