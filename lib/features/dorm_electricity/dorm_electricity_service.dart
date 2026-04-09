import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_logger.dart';
import '../../core/network/network_settings.dart';
import '../../core/network/proxy_mode.dart';

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

  static const _keyCommunityId = 'dorm_community_id';
  static const _keyBuildingId = 'dorm_building_id';
  static const _keyFloorId = 'dorm_floor_id';
  static const _keyRoomId = 'dorm_room_id';
  static const _keyElectricity = 'dorm_cached_electricity';
  static const _keyElectricityUpdatedAt = 'dorm_cached_electricity_updated_at';
  static const refreshWindow = Duration(minutes: 30);
  static const _requestTimeout = Duration(seconds: 12);

  Dio? _dio;
  SharedPreferences? _prefs;
  bool _cacheRestored = false;

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

  Dio _createProxyFallbackDio() {
    final baseOptions = _dio?.options;
    final client = Dio(
      BaseOptions(
        connectTimeout:
            baseOptions?.connectTimeout ?? const Duration(seconds: 10),
        receiveTimeout:
            baseOptions?.receiveTimeout ?? const Duration(seconds: 10),
        sendTimeout: baseOptions?.sendTimeout,
        headers: baseOptions?.headers != null
            ? Map<String, dynamic>.from(baseOptions!.headers)
            : {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                'X-Requested-With': 'XMLHttpRequest',
              },
        responseType: ResponseType.bytes,
      ),
    );
    applyProxyModeToDio(client, ignoreSystemProxy: false);
    return client;
  }

  bool _shouldRetryWithSystemProxy(DioException error) {
    return NetworkSettings.instance.ignoreSystemProxy.value &&
        (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError);
  }

  bool _shouldRetryWithSystemProxyForAny(Object error) {
    if (!NetworkSettings.instance.ignoreSystemProxy.value) return false;
    if (error is TimeoutException) return true;
    if (error is DioException) return _shouldRetryWithSystemProxy(error);
    return false;
  }

  bool _isHostLookupFailure(DioException error) {
    final message = (error.message ?? '').toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('no address associated with hostname');
  }

  Future<Response<T>> _sendWithProxyFallback<T>({
    required String label,
    required Future<Response<T>> Function(Dio dio) request,
  }) async {
    final dio = await _ensureDio();
    try {
      return await request(dio).timeout(_requestTimeout);
    } catch (error) {
      if (!_shouldRetryWithSystemProxyForAny(error)) rethrow;
      AppLogger.instance.info('$label 直连失败，尝试通过系统代理重试');
      final fallbackDio = _createProxyFallbackDio();
      try {
        return await request(fallbackDio).timeout(_requestTimeout);
      } finally {
        fallbackDio.close(force: true);
      }
    }
  }

  void applyProxyMode() {
    final client = _dio;
    if (client == null) return;
    applyProxyModeToDio(
      client,
      ignoreSystemProxy: NetworkSettings.instance.ignoreSystemProxy.value,
    );
  }

  Future<void> restoreCache({bool force = false}) async {
    if (_cacheRestored && !force) return;
    if (force) {
      _prefs = await SharedPreferences.getInstance();
    }
    final prefs = await _ensurePrefs();
    _cachedElectricity = prefs.getDouble(_keyElectricity);
    final updatedAtMillis = prefs.getInt(_keyElectricityUpdatedAt);
    if (updatedAtMillis != null) {
      _lastUpdated = DateTime.fromMillisecondsSinceEpoch(updatedAtMillis);
    }
    _cacheRestored = true;
  }

  Future<bool> hasRoomConfig() async {
    final prefs = await _ensurePrefs();
    return prefs.containsKey(_keyCommunityId) &&
        prefs.containsKey(_keyBuildingId) &&
        prefs.containsKey(_keyFloorId) &&
        prefs.containsKey(_keyRoomId);
  }

  Future<DormRoomConfig?> loadRoomConfig() async {
    final prefs = await _ensurePrefs();
    final communityId = prefs.getString(_keyCommunityId);
    final buildingId = prefs.getString(_keyBuildingId);
    final floorId = prefs.getString(_keyFloorId);
    final roomId = prefs.getString(_keyRoomId);
    if (communityId == null ||
        buildingId == null ||
        floorId == null ||
        roomId == null) {
      return null;
    }
    return DormRoomConfig(
      communityId: communityId,
      buildingId: buildingId,
      floorId: floorId,
      roomId: roomId,
    );
  }

  Future<void> saveRoomConfig(DormRoomConfig config) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_keyCommunityId, config.communityId);
    await prefs.setString(_keyBuildingId, config.buildingId);
    await prefs.setString(_keyFloorId, config.floorId);
    await prefs.setString(_keyRoomId, config.roomId);
  }

  Future<void> clearRoomConfig() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_keyCommunityId);
    await prefs.remove(_keyBuildingId);
    await prefs.remove(_keyFloorId);
    await prefs.remove(_keyRoomId);
    await prefs.remove(_keyElectricity);
    await prefs.remove(_keyElectricityUpdatedAt);
    _cachedElectricity = null;
    _lastUpdated = null;
  }

  String _buildQueryUrl(DormRoomConfig config) {
    return 'http://jdhq.wap.zjxu.edu.cn/DormCharge/BaseElect/queryResult'
        '/ele_id/1'
        '/community_id/${config.communityId}'
        '/building_id/${config.buildingId}'
        '/floor_id/${config.floorId}'
        '/room_id/${config.roomId}';
  }

  Future<double?> fetchElectricity({bool forceRefresh = false}) async {
    try {
      await restoreCache();

      if (!forceRefresh && hasFreshCache) {
        _lastError = null;
        return _cachedElectricity;
      }

      final config = await loadRoomConfig();
      if (config == null) return null;

      final url = _buildQueryUrl(config);
      AppLogger.instance.debug('电费查询 → $url');
      final resp = await _sendWithProxyFallback<List<int>>(
        label: '宿舍电费查询',
        request: (dio) => dio.get<List<int>>(url),
      );
      AppLogger.instance.debug(
        '电费响应 status=${resp.statusCode} bytes=${resp.data?.length}',
      );
      if (resp.data == null) return _cachedElectricity;

      final html = utf8.decode(resp.data!, allowMalformed: true);
      final doc = html_parser.parse(html);
      final text = doc.body?.text ?? '';
      AppLogger.instance.debug(
        '电费页面文本(前200): ${text.length > 200 ? text.substring(0, 200) : text}',
      );

      final match = RegExp(
        r'实际剩余电量\s*[（(]度[)）]\s*(?:[:：]\s*)?([0-9]+(?:\.[0-9]+)?)',
        dotAll: true,
      ).firstMatch(text);

      if (match != null) {
        final value = double.tryParse(match.group(1)!);
        if (value != null) {
          _cachedElectricity = value;
          _lastUpdated = DateTime.now();
          await _persistCache();
          _lastError = null;
          AppLogger.instance.info('电费解析成功: $value 度');
          return value;
        }
      }
      AppLogger.instance.debug('电费正则未匹配，文本长度=${text.length}');
      _lastError = '数据解析失败';
      return _cachedElectricity;
    } on DioException catch (e) {
      AppLogger.instance.error('电费网络错误: ${e.type} ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _lastError = '网络超时';
        return _cachedElectricity;
      }
      if (e.type == DioExceptionType.connectionError) {
        _lastError = _isHostLookupFailure(e)
            ? '域名解析失败，请关闭“忽略系统代理”或连接校园网'
            : '网络不可达';
        return _cachedElectricity;
      }
      _lastError = '未知错误';
      return _cachedElectricity;
    } on TimeoutException {
      AppLogger.instance.error('电费查询超时: 超过 ${_requestTimeout.inSeconds} 秒');
      _lastError = '网络超时';
      return _cachedElectricity;
    } catch (e) {
      AppLogger.instance.error('电费查询异常: $e');
      _lastError = '未知错误';
      return _cachedElectricity;
    }
  }

  String formatElectricity(double? value) {
    if (value == null) return '--';
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  /// 获取园区+楼幢列表（两级嵌套，无需认证）
  Future<List<DormBuilding>> fetchBuildings() async {
    final resp = await _sendWithProxyFallback<List<int>>(
      label: '宿舍楼栋列表',
      request: (dio) => dio.post<List<int>>(
        'http://jdhq.wap.zjxu.edu.cn/dormcharge/base_elect/getParkBuild/ele_id/1',
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      ),
    );
    final json =
        jsonDecode(utf8.decode(resp.data!, allowMalformed: true))
            as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    final result = <DormBuilding>[];
    for (final community in data) {
      final communityId = community['id'].toString();
      final communityName = community['value'] as String;
      for (final building in community['childs'] as List<dynamic>) {
        result.add(
          DormBuilding(
            communityId: communityId,
            buildingId: building['id'].toString(),
            communityName: communityName,
            buildingName: building['value'] as String,
          ),
        );
      }
    }
    return result;
  }

  /// 获取楼层+房间列表（两级嵌套，无需认证）
  Future<List<DormRoom>> fetchRooms(String buildingId) async {
    final resp = await _sendWithProxyFallback<List<int>>(
      label: '宿舍房间列表',
      request: (dio) => dio.post<List<int>>(
        'http://jdhq.wap.zjxu.edu.cn/dormcharge/base_elect/getFloorRoom/ele_id/1',
        data: 'building_id=$buildingId',
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      ),
    );
    final json =
        jsonDecode(utf8.decode(resp.data!, allowMalformed: true))
            as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    final result = <DormRoom>[];
    for (final floor in data) {
      final floorId = floor['id'].toString();
      final floorName = floor['value'] as String;
      for (final room in floor['childs'] as List<dynamic>) {
        result.add(
          DormRoom(
            floorId: floorId,
            roomId: room['id'].toString(),
            floorName: floorName,
            roomName: room['value'] as String,
          ),
        );
      }
    }
    return result;
  }

  Dio _createDio() {
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'X-Requested-With': 'XMLHttpRequest',
        },
        responseType: ResponseType.bytes,
      ),
    );
    applyProxyModeToDio(
      client,
      ignoreSystemProxy: NetworkSettings.instance.ignoreSystemProxy.value,
    );
    return client;
  }

  Future<Dio> _ensureDio() async {
    final existing = _dio;
    if (existing != null) return existing;

    await NetworkSettings.instance.ensureInitialized();
    final created = _createDio();
    _dio = created;
    return created;
  }

  Future<SharedPreferences> _ensurePrefs() async {
    final prefs = _prefs;
    if (prefs != null) return prefs;
    final created = await SharedPreferences.getInstance();
    _prefs = created;
    return created;
  }

  Future<void> _persistCache() async {
    final prefs = await _ensurePrefs();
    final value = _cachedElectricity;
    final updatedAt = _lastUpdated;
    if (value == null || updatedAt == null) return;
    await prefs.setDouble(_keyElectricity, value);
    await prefs.setInt(
      _keyElectricityUpdatedAt,
      updatedAt.millisecondsSinceEpoch,
    );
  }

  @visibleForTesting
  void debugSetCachedElectricity(double? value, {DateTime? updatedAt}) {
    _cachedElectricity = value;
    _lastUpdated = updatedAt;
    _cacheRestored = true;
  }
}
