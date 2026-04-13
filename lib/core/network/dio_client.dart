/// Stub implementation for open source release.
/// Real network client implementation is not included.
/// 
/// This file provides stub implementations to allow the UI code to compile.

import 'package:flutter/foundation.dart';

class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  Future<void> init() async {
    // Stub - not implemented
  }

  Future<void> ensureInitialized() async {
    // Stub - not implemented
  }

  void applyProxyMode() {
    // Stub - not implemented
  }

  void updateBaseUrl(String baseUrl) {
    // Stub - not implemented
  }

  @visibleForTesting
  void debugReset() {
    // Stub - not implemented
  }
}