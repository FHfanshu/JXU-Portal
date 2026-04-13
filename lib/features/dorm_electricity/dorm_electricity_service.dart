/// Stub implementation for open source release.
/// Real dorm electricity service implementation is not included.
/// 
/// This file provides type definitions and stub implementations
/// to allow the UI code to compile without the actual fetching logic.

import 'package:flutter/foundation.dart';

class DormRoomConfig {
  final String communityId;
  final String buildingId;
  final String floorId;
  final String roomId;

  const DormRoomConfig({
    required this.communityId,
    required this.buildingId,
    required this.floorId,
    required this.roomId,
  });
}

class DormBuilding {
  final String communityId;
  final String buildingId;
  final String communityName;
  final String buildingName;

  const DormBuilding({
    required this.communityId,
    required this.buildingId,
    required this.communityName,
    required this.buildingName,
  });
}

class DormRoom {
  final String floorId;
  final String roomId;
  final String floorName;
  final String roomName;

  const DormRoom({
    required this.floorId,
    required this.roomId,
    required this.floorName,
    required this.roomName,
  });
}

class DormElectricityService {
  DormElectricityService._();
  static final DormElectricityService instance = DormElectricityService._();

  static const refreshWindow = Duration(minutes: 30);

  double? _cachedElectricity;
  DateTime? _lastUpdated;
  double? get cachedElectricity => _cachedElectricity;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasFreshCache {
    final updatedAt = _lastUpdated;
    if (_cachedElectricity == null || updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) <= refreshWindow;
  }

  String? _lastError;
  String? get lastError => _lastError;

  void applyProxyMode() {
    // Stub - not implemented
  }

  Future<void> restoreCache({bool force = false}) async {
    // Stub - not implemented
  }

  Future<bool> hasRoomConfig() async {
    // Stub - not implemented
    return false;
  }

  Future<DormRoomConfig?> loadRoomConfig() async {
    // Stub - not implemented
    return null;
  }

  Future<void> saveRoomConfig(DormRoomConfig config) async {
    // Stub - not implemented
  }

  Future<void> clearRoomConfig() async {
    // Stub - not implemented
    _cachedElectricity = null;
    _lastUpdated = null;
  }

  Future<double?> fetchElectricity({bool forceRefresh = false}) async {
    // Stub - not implemented
    _lastError = 'Not implemented in open source version';
    return _cachedElectricity;
  }

  String formatElectricity(double? value) {
    if (value == null) return '--';
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Future<List<DormBuilding>> fetchBuildings() async {
    // Stub - not implemented
    return [];
  }

  Future<List<DormRoom>> fetchRooms(String buildingId) async {
    // Stub - not implemented
    return [];
  }

  @visibleForTesting
  void debugSetCachedElectricity(double? value, {DateTime? updatedAt}) {
    _cachedElectricity = value;
    _lastUpdated = updatedAt;
  }

  @visibleForTesting
  void debugReset() {
    _cachedElectricity = null;
    _lastUpdated = null;
    _lastError = null;
  }
}