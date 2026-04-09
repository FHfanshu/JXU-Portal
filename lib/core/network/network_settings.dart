import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkSettings {
  NetworkSettings._();

  static final NetworkSettings instance = NetworkSettings._();

  static const _keyIgnoreSystemProxy = 'ignore_system_proxy';

  final ValueNotifier<bool> ignoreSystemProxy = ValueNotifier<bool>(true);
  Future<void>? _initFuture;

  Future<void> init() async {
    await ensureInitialized();
  }

  Future<void> ensureInitialized() async {
    final existing = _initFuture;
    if (existing != null) return existing;

    final future = _load();
    _initFuture = future;
    try {
      await future;
    } catch (_) {
      if (identical(_initFuture, future)) {
        _initFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    ignoreSystemProxy.value = prefs.getBool(_keyIgnoreSystemProxy) ?? true;
  }

  Future<void> setIgnoreSystemProxy(bool value) async {
    if (ignoreSystemProxy.value == value) return;
    ignoreSystemProxy.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIgnoreSystemProxy, value);
  }

  @visibleForTesting
  void debugReset({bool ignoreSystemProxyValue = true}) {
    _initFuture = null;
    ignoreSystemProxy.value = ignoreSystemProxyValue;
  }
}
