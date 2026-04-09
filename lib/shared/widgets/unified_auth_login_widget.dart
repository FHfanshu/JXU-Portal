import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/auth/credential_store.dart';
import '../../core/auth/unified_auth.dart';

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

  @override
  void initState() {
    super.initState();
    _bootstrapLoginState();
  }

  Future<void> _bootstrapLoginState() async {
    await _loadSaved();
    await Future<void>.delayed(Duration.zero);

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

    await Future<void>.delayed(Duration.zero);
    await _refreshCaptcha();
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
          await UnifiedAuthService.instance.fetchCaptcha(
            serviceUrl: widget.serviceUrl,
          );
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _captchaBytes = bytes;
        _error = null;
      });
    } on UnifiedAuthCaptchaException catch (error) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        _error = '统一认证验证码加载失败，请点击重试';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.account_balance_outlined, size: 64, color: cs.primary),
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
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(
              labelText: '一卡通账号',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
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
                          ? cs.error
                          : cs.outline,
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
                          child: Icon(Icons.refresh, color: cs.error, size: 28),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: cs.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
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
            '验证码点击可刷新，登录成功后会自动进入对应服务',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
