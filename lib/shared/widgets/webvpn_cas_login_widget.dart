import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/auth/credential_store.dart';
import '../../core/auth/zhengfang_auth.dart';

class WebVpnCasLoginWidget extends StatefulWidget {
  const WebVpnCasLoginWidget({
    super.key,
    this.title = '登录一卡通',
    this.description = '账号为校园一卡通号',
    required this.onLoginSuccess,
  });

  final String title;
  final String description;
  final VoidCallback onLoginSuccess;

  @override
  State<WebVpnCasLoginWidget> createState() => _WebVpnCasLoginWidgetState();
}

class _WebVpnCasLoginWidgetState extends State<WebVpnCasLoginWidget> {
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  Uint8List? _captchaBytes;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _refreshCaptcha();
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final creds = await CredentialStore.instance.loadUnifiedAuthCredentials();
    if (creds == null || !mounted) return;

    setState(() {
      _accountCtrl.text = creds.$1;
      _passwordCtrl.text = creds.$2;
    });
  }

  Future<void> _refreshCaptcha() async {
    try {
      final bytes = await ZhengfangAuth.instance.fetchWebVpnCasCaptcha();
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _captchaBytes = bytes;
        _error = null;
      });
    } on CaptchaException catch (error) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captchaBytes = null;
        _error = 'WebVPN 验证码加载失败，请重试';
      });
    }
  }

  Future<void> _login() async {
    final account = _accountCtrl.text.trim();
    final password = _passwordCtrl.text;
    final captcha = _captchaCtrl.text.trim();
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
        widget.onLoginSuccess();
      case WebVpnCasFailure(:final message):
        setState(() {
          _loading = false;
          _error = message;
        });
        _captchaCtrl.clear();
        _refreshCaptcha();
    }
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
          Icon(Icons.vpn_lock_outlined, size: 64, color: cs.primary),
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
            controller: _passwordCtrl,
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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
