import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/auth/unified_auth.dart';
import '../../core/auth/zhengfang_auth.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import 'changxing_jiada_model.dart';

class ChangxingAuthExpiredException implements Exception {
  ChangxingAuthExpiredException([this.message = '畅行嘉大登录已失效，请重新登录']);

  final String message;

  @override
  String toString() => message;
}

class ChangxingCasLoginException implements Exception {
  ChangxingCasLoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// CAS session 无效，需要重新登录一卡通。
class ChangxingNeedUnifiedAuthException implements Exception {
  @override
  String toString() => '一卡通登录已失效，请重新登录';
}

@immutable
class ChangxingSubmitRequest {
  const ChangxingSubmitRequest({required this.path, required this.payload});

  final String path;
  final Map<String, dynamic> payload;
}

class ChangxingJiadaService {
  ChangxingJiadaService._();
  static final ChangxingJiadaService instance = ChangxingJiadaService._();

  static const _baseUrl = 'https://zhx.zjxu.edu.cn/api';
  static const _casLoginUrl = 'https://zhx.zjxu.edu.cn/api/cas_wap_login';
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'zjxu_changxing_token';

  String? _token;
  bool _restored = false;

  bool get hasToken => (_token ?? '').isNotEmpty;

  Future<void> restoreSession() async {
    if (_restored) return;
    _token = await _storage.read(key: _keyToken);
    _restored = true;
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _storage.write(key: _keyToken, value: token);
  }

  Future<void> _clearToken() async {
    _token = null;
    await _storage.delete(key: _keyToken);
  }

  Future<void> logout() async {
    await _clearToken();
  }

  /// 通过 CAS SSO 登录畅行嘉大。
  /// 前提：用户已通过 UnifiedAuthService 完成一卡通登录。
  Future<void> loginViaCas() async {
    await DioClient.instance.ensureInitialized();
    final dio = DioClient.instance.dio;
    AppLogger.instance.debug('畅行嘉大：开始 CAS SSO 登录...');

    try {
      // 1. 发起 CAS 登录，手动跟随重定向链以提取 tokenId
      var nextUrl = _buildWebVpnUrl(_casLoginUrl);
      String? tokenId;
      var sawWebVpnRelay = false;

      for (var i = 0; i < 10; i++) {
        final response = await dio.get<String>(
          nextUrl,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 1000,
            responseType: ResponseType.plain,
          ),
        );

        final statusCode = response.statusCode ?? 0;
        final location = response.headers.value('location') ?? '';
        final body = response.data ?? '';

        if (statusCode >= 300 && statusCode < 400 && location.isNotEmpty) {
          final resolvedLocation = _resolveRedirectUrl(nextUrl, location);
          // 检查重定向 URL 中是否包含 tokenId
          final uri = Uri.tryParse(resolvedLocation);
          if (uri != null) {
            final tid = uri.queryParameters['tokenId'];
            if (tid != null && tid.isNotEmpty) {
              tokenId = tid;
              AppLogger.instance.debug('畅行嘉大：从重定向中提取到 tokenId');
              break;
            }
          }
          if (_isWebVpnAuthEntryUrl(resolvedLocation)) {
            sawWebVpnRelay = true;
            AppLogger.instance.debug('畅行嘉大：进入 WebVPN 登录中转，继续跟随重定向');
          }
          nextUrl = resolvedLocation;
          continue;
        }

        // 非重定向响应，检查最终 URL 是否包含 tokenId
        final finalUri = response.realUri;
        final tid = finalUri.queryParameters['tokenId'];
        if (tid != null && tid.isNotEmpty) {
          tokenId = tid;
          AppLogger.instance.debug('畅行嘉大：从最终 URL 中提取到 tokenId');
        }
        if (tokenId == null &&
            (sawWebVpnRelay ||
                _isWebVpnAuthResponse(finalUri.toString(), body))) {
          AppLogger.instance.info('畅行嘉大：WebVPN session 已失效，需要重新登录一卡通');
          throw ChangxingNeedUnifiedAuthException();
        }
        break;
      }

      if (tokenId == null || tokenId.isEmpty) {
        AppLogger.instance.info('畅行嘉大：SSO 链路结束但未获取到 tokenId');
        throw ChangxingCasLoginException('畅行嘉大登录未完成，请稍后重试');
      }

      // 2. 用 tokenId 换取 JWT token
      final tokenResp = await dio.get<Map<String, dynamic>>(
        _buildWebVpnUrl('$_baseUrl/getToken'),
        queryParameters: {'tokenId': tokenId},
        options: Options(
          responseType: ResponseType.json,
          headers: {'token': '0'},
        ),
      );

      final json = tokenResp.data ?? <String, dynamic>{};
      final data = json['data'] as Map<String, dynamic>? ?? {};
      final code = data['code']?.toString() ?? '';
      if (code != '20000') {
        final msg = data['msg']?.toString() ?? '获取 token 失败';
        throw ChangxingCasLoginException(msg);
      }

      final jwtToken = data['token']?.toString().trim() ?? '';
      if (jwtToken.isEmpty) {
        throw ChangxingCasLoginException('CAS 认证成功但未获取到 token');
      }

      await _saveToken(jwtToken);
      AppLogger.instance.info('畅行嘉大 CAS SSO 登录成功');
    } on DioException catch (e) {
      AppLogger.instance.error('畅行嘉大 CAS 登录网络异常: ${e.type} ${e.message}');
      throw ChangxingCasLoginException('网络异常：${e.message}');
    }
  }

  Future<ChangxingUserProfile> fetchUserProfile() async {
    final json = await _postJson('/user/getUserDetail', {});
    final code = _extractCode(json);
    if (code != '20000') {
      throw ChangxingCasLoginException(
        _extractMessage(json, fallback: '获取用户信息失败'),
      );
    }
    final body = _extractDataMap(json)['body'] as Map<String, dynamic>? ?? {};
    return ChangxingUserProfile.fromJson(body);
  }

  Future<int> fetchUnreadCount() async {
    final json = await _get('/msg/getNoReadCount');
    final code = _extractCode(json);
    if (code != '20000') return 0;
    final data = _extractDataMap(json);
    final count = data['count'];
    if (count is int) return count;
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }

  Future<List<ChangxingApplication>> fetchApplications({
    int page = 1,
    int pageSize = 20,
    int status = 999,
  }) async {
    final json = await _get(
      '/approvalForm/listPage/bystudent',
      query: {'current': '$page', 'pageSize': '$pageSize', 'status': '$status'},
    );
    final code = _extractCode(json);
    if (code != '20000') {
      throw ChangxingCasLoginException(
        _extractMessage(json, fallback: '获取申请列表失败'),
      );
    }
    final body = _extractDataMap(json)['body'] as Map<String, dynamic>? ?? {};
    final records = (body['records'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChangxingApplication.fromJson)
        .toList();
    return records;
  }

  Future<ChangxingApplicationDetail> fetchApplicationDetail(int id) async {
    final json = await _postForm('/approvalForm/getOne', {'id': '$id'});
    _ensureSuccess(json, fallback: '获取申请详情失败');
    final data = _extractDataMap(json)['data'] as Map<String, dynamic>? ?? {};
    return ChangxingApplicationDetail.fromJson(data);
  }

  Future<List<ChangxingAreaNode>> fetchAreaChildren(int parentId) async {
    final json = await _get(
      '/area/getChildArea',
      query: {'parentId': '$parentId'},
    );
    _ensureSuccess(json, fallback: '获取地区信息失败');
    final body =
        _extractDataMap(json)['body'] as List<dynamic>? ?? const <dynamic>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(ChangxingAreaNode.fromJson)
        .toList();
  }

  Future<List<ChangxingAreaNode>> fetchAreaParents(int areaId) async {
    final json = await _get(
      '/area/getParentArea',
      query: {'areaId': '$areaId'},
    );
    _ensureSuccess(json, fallback: '获取上级地区失败');
    final body =
        _extractDataMap(json)['body'] as List<dynamic>? ?? const <dynamic>[];
    return body
        .whereType<Map<String, dynamic>>()
        .map(ChangxingAreaNode.fromJson)
        .toList();
  }

  Future<bool> fetchFanxiaoEnableFlag() async {
    try {
      final json = await _get(
        '/dict/getDictList',
        query: {'labels': 'SYSTEM_LABEL_fanxiaoEnable', 'pageSize': '10000'},
      );
      final code = _extractCode(json);
      if (code != '20000') return false;
      final body = _extractDataMap(json)['body'] as Map<String, dynamic>? ?? {};
      final records = body['records'] as List<dynamic>? ?? const <dynamic>[];
      if (records.isEmpty) return false;
      final first = records.first as Map<String, dynamic>? ?? {};
      return first['ename']?.toString() == '1';
    } catch (_) {
      return false;
    }
  }

  Future<String?> fetchImageByMd5(String md5) async {
    if (md5.trim().isEmpty) return null;
    final json = await _get('/image/getOne', query: {'md5': md5.trim()});
    _ensureSuccess(json, fallback: '获取附件预览失败');
    final data = _extractDataMap(json)['data'] as Map<String, dynamic>? ?? {};
    final base64 = data['base64']?.toString().trim() ?? '';
    if (base64.isEmpty) return null;
    return 'data:image/png;base64,$base64';
  }

  Future<ChangxingUploadResult> uploadAttachment(
    String filePath,
    String fileName,
  ) async {
    await DioClient.instance.ensureInitialized();
    await restoreSession();
    final token = _token ?? '';
    if (token.isEmpty) {
      throw ChangxingAuthExpiredException();
    }

    final effectiveName = fileName.trim().isEmpty
        ? filePath.split(RegExp(r'[\\/]')).last
        : fileName.trim();
    final formData = FormData.fromMap({
      'valiFace': 'false',
      'file': await MultipartFile.fromFile(filePath, filename: effectiveName),
    });

    final response = await DioClient.instance.dio.postUri<Map<String, dynamic>>(
      Uri.parse(
        _buildWebVpnUrl('https://zhx.zjxu.edu.cn/api/image/add/single'),
      ),
      data: formData,
      options: Options(
        headers: {'token': token},
        responseType: ResponseType.json,
      ),
    );

    final json = response.data ?? <String, dynamic>{};
    final code = _extractCode(json);
    if (code == '500001') {
      await _clearToken();
      throw ChangxingAuthExpiredException(
        _extractMessage(json, fallback: '令牌错误，请重新登录'),
      );
    }
    _ensureSuccess(json, fallback: '上传附件失败');
    final data = _extractDataMap(json)['data'] as Map<String, dynamic>? ?? {};
    return ChangxingUploadResult(
      md5: data['md5']?.toString().trim() ?? '',
      base64: data['base64']?.toString().trim() ?? '',
    );
  }

  Future<void> submitLeaveRequest({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
    String img = '',
    String annex = '',
  }) async {
    final request = buildLeaveRequestSubmitRequest(
      id: id,
      startTime: startTime,
      endTime: endTime,
      descr: descr,
      toAreaCode: toAreaCode,
      toAddr: toAddr,
      emergencyContact: emergencyContact,
      emergencyPhone: emergencyPhone,
      userPhone: userPhone,
      trafficTools: trafficTools,
      img: img,
      annex: annex,
    );
    final json = await _postJson(request.path, request.payload);
    _ensureSuccess(json, fallback: id == null ? '提交请假失败' : '修改请假失败');
  }

  Future<void> submitLeaveSchool({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
  }) async {
    final request = buildLeaveSchoolSubmitRequest(
      id: id,
      startTime: startTime,
      endTime: endTime,
      descr: descr,
      toAreaCode: toAreaCode,
      toAddr: toAddr,
      emergencyContact: emergencyContact,
      emergencyPhone: emergencyPhone,
      userPhone: userPhone,
      trafficTools: trafficTools,
    );
    final json = await _postJson(request.path, request.payload);
    _ensureSuccess(json, fallback: id == null ? '提交离校失败' : '修改离校失败');
  }

  Future<void> submitBackSchool({
    int? id,
    required String userPhone,
    required DateTime startTime,
    required String trafficTool,
    required String trafficDetail,
    required String nativePlace,
    required int fromAreaCode,
    required String emergencyContact,
    required String emergencyPhone,
    required int backStatus,
    required String notBackReason,
    String img = '',
    String annex = '',
  }) async {
    final request = buildBackSchoolSubmitRequest(
      id: id,
      userPhone: userPhone,
      startTime: startTime,
      trafficTool: trafficTool,
      trafficDetail: trafficDetail,
      nativePlace: nativePlace,
      fromAreaCode: fromAreaCode,
      emergencyContact: emergencyContact,
      emergencyPhone: emergencyPhone,
      backStatus: backStatus,
      notBackReason: notBackReason,
      img: img,
      annex: annex,
    );
    final json = await _postJson(request.path, request.payload);
    _ensureSuccess(json, fallback: id == null ? '提交返校失败' : '修改返校失败');
  }

  Future<void> submitOvertime({int? id, required String descr}) async {
    final request = buildOvertimeSubmitRequest(id: id, descr: descr);
    final json = await _postJson(request.path, request.payload);
    _ensureSuccess(json, fallback: id == null ? '提交超时失败' : '修改超时失败');
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildLeaveRequestSubmitRequest({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
    String img = '',
    String annex = '',
  }) {
    final payload = <String, dynamic>{
      'startTime': startTime,
      'endTime': endTime,
      'descr': descr,
      'toAreaCode': toAreaCode,
      'toAddr': toAddr,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'userPhone': userPhone,
      'trafficTool': trafficTools.join(','),
      'img': img,
      'annex': annex,
      'type': 1,
    };
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: id == null ? '/approvalForm/qingjia/add' : '/approvalForm/edit',
      payload: payload,
    );
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildLeaveSchoolSubmitRequest({
    int? id,
    required DateTime startTime,
    required DateTime endTime,
    required String descr,
    required int toAreaCode,
    required String toAddr,
    required String emergencyContact,
    required String emergencyPhone,
    required String userPhone,
    required List<String> trafficTools,
  }) {
    final payload = <String, dynamic>{
      'startTime': startTime,
      'endTime': endTime,
      'descr': descr,
      'toAreaCode': toAreaCode,
      'toAddr': toAddr,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'userPhone': userPhone,
      'trafficTool': trafficTools.join(','),
      'type': 2,
    };
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: id == null ? '/approvalForm/lixiao/add' : '/approvalForm/edit',
      payload: payload,
    );
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildBackSchoolSubmitRequest({
    int? id,
    required String userPhone,
    required DateTime startTime,
    required String trafficTool,
    required String trafficDetail,
    required String nativePlace,
    required int fromAreaCode,
    required String emergencyContact,
    required String emergencyPhone,
    required int backStatus,
    required String notBackReason,
    String img = '',
    String annex = '',
  }) {
    final payload = <String, dynamic>{
      'userPhone': userPhone,
      'startTime': startTime,
      'trafficTool': trafficTool,
      'trafficDetail': trafficDetail,
      'nativePlace': nativePlace,
      'fromAreaCode': fromAreaCode,
      'emergencyContact': emergencyContact,
      'emergencyPhone': emergencyPhone,
      'backStatus': backStatus,
      'notBackReason': notBackReason,
      'img': img,
      'annex': annex,
      'type': 3,
    };
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: id == null ? '/approvalForm/fanxiao/add' : '/approvalForm/edit',
      payload: payload,
    );
  }

  @visibleForTesting
  static ChangxingSubmitRequest buildOvertimeSubmitRequest({
    int? id,
    required String descr,
  }) {
    final payload = <String, dynamic>{'type': 4, 'descr': descr};
    if (id != null) payload['id'] = id;
    return ChangxingSubmitRequest(
      path: '/approvalForm/overtime/add',
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    bool requiresToken = true,
    Map<String, String>? query,
  }) async {
    return _request(
      path: path,
      method: 'GET',
      requiresToken: requiresToken,
      query: query,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    bool requiresToken = true,
  }) async {
    return _request(
      path: path,
      method: 'POST',
      requiresToken: requiresToken,
      data: body,
      contentType: Headers.jsonContentType,
    );
  }

  Future<Map<String, dynamic>> _postForm(
    String path,
    Map<String, dynamic> body, {
    bool requiresToken = true,
  }) async {
    return _request(
      path: path,
      method: 'POST',
      requiresToken: requiresToken,
      data: body,
      contentType: Headers.formUrlEncodedContentType,
    );
  }

  Future<Map<String, dynamic>> _request({
    required String path,
    required String method,
    required bool requiresToken,
    Object? data,
    String? contentType,
    Map<String, String>? query,
  }) async {
    await DioClient.instance.ensureInitialized();
    await restoreSession();
    final token = _token ?? '';
    if (requiresToken && token.isEmpty) {
      throw ChangxingAuthExpiredException();
    }

    final uri = Uri.parse(
      _buildWebVpnUrl(
        Uri.parse('$_baseUrl$path').replace(queryParameters: query).toString(),
      ),
    );
    final headers = <String, String>{};
    if (requiresToken) {
      headers['token'] = token;
    }

    final response = await DioClient.instance.dio
        .requestUri<Map<String, dynamic>>(
          uri,
          data: data,
          options: Options(
            method: method,
            contentType: contentType,
            headers: headers,
            responseType: ResponseType.json,
          ),
        );

    final json = response.data ?? <String, dynamic>{};
    final code = _extractCode(json);
    if (code == '500001') {
      await _clearToken();
      throw ChangxingAuthExpiredException(
        _extractMessage(json, fallback: '令牌错误，请重新登录'),
      );
    }
    return json;
  }

  String _extractCode(Map<String, dynamic> json) {
    final data = _extractDataMap(json);
    return data['code']?.toString() ?? json['code']?.toString() ?? '';
  }

  void _ensureSuccess(Map<String, dynamic> json, {required String fallback}) {
    final code = _extractCode(json);
    if (code != '20000') {
      throw ChangxingCasLoginException(
        _extractMessage(json, fallback: fallback),
      );
    }
  }

  String _extractMessage(
    Map<String, dynamic> json, {
    required String fallback,
  }) {
    final data = _extractDataMap(json);
    return data['msg']?.toString() ??
        data['errmsg']?.toString() ??
        json['msg']?.toString() ??
        fallback;
  }

  Map<String, dynamic> _extractDataMap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    return <String, dynamic>{};
  }

  String _resolveRedirectUrl(String baseUrl, String location) {
    if (location.startsWith('/') || !location.contains('://')) {
      return Uri.parse(baseUrl).resolve(location).toString();
    }
    return location;
  }

  String _buildWebVpnUrl(String url) {
    return ZhengfangAuth.instance.buildWebVpnProxyUrl(url);
  }

  bool _isWebVpnAuthEntryUrl(String url) {
    if (isZhengfangGatewayLoginUrl(url)) return true;

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.toLowerCase() != 'webvpn.zjxu.edu.cn') {
      return false;
    }

    return uri.path.toLowerCase().contains('/cas/login');
  }

  bool _isWebVpnAuthResponse(String url, String html) {
    if (_isWebVpnAuthEntryUrl(url)) return true;

    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.toLowerCase() != 'webvpn.zjxu.edu.cn') {
      return false;
    }

    if (uri.path == '/' || uri.path.toLowerCase() == '/m/portal') {
      return true;
    }

    return looksLikeUnifiedAuthLoginHtml(html);
  }

  @visibleForTesting
  static bool isUnifiedAuthLoginFormResponse(String url, String html) {
    return isUnifiedAuthLoginEntryUrl(url) &&
        looksLikeUnifiedAuthLoginHtml(html);
  }
}
