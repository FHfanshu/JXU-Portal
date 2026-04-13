/// Stub implementation for open source release.
/// Real network settings implementation is not included.

import 'package:flutter/foundation.dart';

class NetworkSettings {
  NetworkSettings._();
  static final NetworkSettings instance = NetworkSettings._();

  final ValueNotifier<bool> ignoreSystemProxy = ValueNotifier<bool>(true);

  Future<void> init() async {
    // Stub - not implemented
  }

  Future<void> ensureInitialized() async {
    // Stub - not implemented
  }

  Future<void> setIgnoreSystemProxy(bool value) async {
    ignoreSystemProxy.value = value;
  }

  @visibleForTesting
  void debugReset({bool ignoreSystemProxyValue = true}) {
    ignoreSystemProxy.value = ignoreSystemProxyValue;
  }
}