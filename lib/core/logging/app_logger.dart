import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { debug, info, warn, error }

enum LogCategory { auth, network, webview, ui, storage, bootstrap, general }

class LogConfig {
  const LogConfig({
    required this.minimumLevel,
    required this.enabledCategories,
    required this.webviewConsoleEnabled,
    required this.webviewLifecycleEnabled,
    required this.networkVerboseEnabled,
  });

  const LogConfig.defaults()
    : minimumLevel = kDebugMode ? LogLevel.debug : LogLevel.info,
      enabledCategories = const {
        LogCategory.auth,
        LogCategory.network,
        LogCategory.webview,
        LogCategory.ui,
        LogCategory.storage,
        LogCategory.bootstrap,
        LogCategory.general,
      },
      webviewConsoleEnabled = false,
      webviewLifecycleEnabled = true,
      networkVerboseEnabled = false;

  final LogLevel minimumLevel;
  final Set<LogCategory> enabledCategories;
  final bool webviewConsoleEnabled;
  final bool webviewLifecycleEnabled;
  final bool networkVerboseEnabled;

  LogConfig copyWith({
    LogLevel? minimumLevel,
    Set<LogCategory>? enabledCategories,
    bool? webviewConsoleEnabled,
    bool? webviewLifecycleEnabled,
    bool? networkVerboseEnabled,
  }) {
    return LogConfig(
      minimumLevel: minimumLevel ?? this.minimumLevel,
      enabledCategories: enabledCategories ?? this.enabledCategories,
      webviewConsoleEnabled:
          webviewConsoleEnabled ?? this.webviewConsoleEnabled,
      webviewLifecycleEnabled:
          webviewLifecycleEnabled ?? this.webviewLifecycleEnabled,
      networkVerboseEnabled:
          networkVerboseEnabled ?? this.networkVerboseEnabled,
    );
  }
}

class LogEntry {
  static const String logPrefix = '[JXU]';

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final String? error;
  final String? stackTrace;

  String get formatted {
    final ts = timestamp.toIso8601String();
    final tag = level.name.toUpperCase();
    final categoryTag = category.name;
    final errorSuffix = error == null || error!.isEmpty
        ? ''
        : ' | error=$error';
    final stackSuffix = stackTrace == null || stackTrace!.isEmpty
        ? ''
        : '\n$stackTrace';
    return '$logPrefix [$ts] [$tag] [$categoryTag] $message$errorSuffix$stackSuffix';
  }

  @override
  String toString() => formatted;
}

class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const int _bufferCapacity = 500;
  static const int _retentionDays = 3;
  static const String _prefsEnabledKey = 'app_logger_enabled';
  static const String _prefsMinLevelKey = 'app_logger_min_level';
  static const String _prefsEnabledCategoriesKey =
      'app_logger_enabled_categories';
  static const String _prefsWebviewConsoleKey = 'app_logger_webview_console';
  static const String _prefsWebviewLifecycleKey =
      'app_logger_webview_lifecycle';
  static const String _prefsNetworkVerboseKey = 'app_logger_network_verbose';

  static final RegExp _studentIdPattern = RegExp(r'\d{10,12}');
  static final RegExp _mmPattern = RegExp(r'mm=[^\s&;]+');
  static final RegExp _passwordPattern = RegExp(r'password=[^\s&;]+');
  static final RegExp _sessionIdPattern = RegExp(r'JSESSIONID=[^\s;]+');
  static final RegExp _phonePattern = RegExp(r'1[3-9]\d{9}');

  final ListQueue<LogEntry> _buffer = ListQueue<LogEntry>(_bufferCapacity);

  final ValueNotifier<bool> loggingEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<LogConfig> config = ValueNotifier<LogConfig>(
    const LogConfig.defaults(),
  );

  Directory? _logDir;
  SharedPreferences? _prefs;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    loggingEnabled.value = prefs.getBool(_prefsEnabledKey) ?? true;
    config.value = LogConfig(
      minimumLevel: _parseLevel(
        prefs.getString(_prefsMinLevelKey),
        fallback: const LogConfig.defaults().minimumLevel,
      ),
      enabledCategories: _parseCategories(
        prefs.getStringList(_prefsEnabledCategoriesKey),
      ),
      webviewConsoleEnabled:
          prefs.getBool(_prefsWebviewConsoleKey) ??
          const LogConfig.defaults().webviewConsoleEnabled,
      webviewLifecycleEnabled:
          prefs.getBool(_prefsWebviewLifecycleKey) ??
          const LogConfig.defaults().webviewLifecycleEnabled,
      networkVerboseEnabled:
          prefs.getBool(_prefsNetworkVerboseKey) ??
          const LogConfig.defaults().networkVerboseEnabled,
    );

    if (kDebugMode) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _logDir = Directory('${appDir.path}/logs');
        if (!_logDir!.existsSync()) {
          _logDir!.createSync(recursive: true);
        }
        await _cleanupOldLogs();
      } catch (_) {
        // File system unavailable (e.g. tests) - silently degrade.
      }
    }
  }

  Future<void> setEnabled(bool value) async {
    loggingEnabled.value = value;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool(_prefsEnabledKey, value);
  }

  Future<void> updateConfig(LogConfig nextConfig) async {
    config.value = nextConfig;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_prefsMinLevelKey, nextConfig.minimumLevel.name);
    await prefs.setStringList(
      _prefsEnabledCategoriesKey,
      nextConfig.enabledCategories.map((category) => category.name).toList(),
    );
    await prefs.setBool(
      _prefsWebviewConsoleKey,
      nextConfig.webviewConsoleEnabled,
    );
    await prefs.setBool(
      _prefsWebviewLifecycleKey,
      nextConfig.webviewLifecycleEnabled,
    );
    await prefs.setBool(
      _prefsNetworkVerboseKey,
      nextConfig.networkVerboseEnabled,
    );
  }

  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_buffer.toList());

  void debug(String message) {
    log(LogLevel.debug, LogCategory.general, message);
  }

  void info(String message) {
    log(LogLevel.info, LogCategory.general, message);
  }

  void warn(String message) {
    log(LogLevel.warn, LogCategory.general, message);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    log(
      LogLevel.error,
      LogCategory.general,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void log(
    LogLevel level,
    LogCategory category,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool force = false,
  }) {
    if (!kDebugMode && !force) return;
    if (!loggingEnabled.value && !force) return;

    final activeConfig = config.value;
    if (!_shouldLog(level, category, activeConfig, force: force)) {
      return;
    }

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: _scrub(message),
      error: error == null ? null : _scrub('$error'),
      stackTrace: stackTrace == null ? null : _scrub('$stackTrace'),
    );

    if (_buffer.length >= _bufferCapacity) {
      _buffer.removeFirst();
    }
    _buffer.addLast(entry);

    debugPrint(entry.formatted);
    _appendToFile(entry);
  }

  void auth(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool force = false,
  }) {
    log(
      level,
      LogCategory.auth,
      message,
      error: error,
      stackTrace: stackTrace,
      force: force,
    );
  }

  void network(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool force = false,
  }) {
    log(
      level,
      LogCategory.network,
      message,
      error: error,
      stackTrace: stackTrace,
      force: force,
    );
  }

  void webview(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool force = false,
  }) {
    log(
      level,
      LogCategory.webview,
      message,
      error: error,
      stackTrace: stackTrace,
      force: force,
    );
  }

  void ui(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool force = false,
  }) {
    log(
      level,
      LogCategory.ui,
      message,
      error: error,
      stackTrace: stackTrace,
      force: force,
    );
  }

  void storage(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool force = false,
  }) {
    log(
      level,
      LogCategory.storage,
      message,
      error: error,
      stackTrace: stackTrace,
      force: force,
    );
  }

  void bootstrap(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    bool force = false,
  }) {
    log(
      level,
      LogCategory.bootstrap,
      message,
      error: error,
      stackTrace: stackTrace,
      force: force,
    );
  }

  bool _shouldLog(
    LogLevel level,
    LogCategory category,
    LogConfig activeConfig, {
    required bool force,
  }) {
    if (force || level == LogLevel.error) {
      return true;
    }
    if (level.index < activeConfig.minimumLevel.index) {
      return false;
    }
    return activeConfig.enabledCategories.contains(category);
  }

  String _scrub(String input) {
    var result = input;
    result = result.replaceAll(_sessionIdPattern, 'JSESSIONID=[REDACTED]');
    result = result.replaceAll(_passwordPattern, 'password=[REDACTED]');
    result = result.replaceAll(_mmPattern, 'mm=[REDACTED]');
    result = result.replaceAll(_phonePattern, '[REDACTED]');
    result = result.replaceAll(_studentIdPattern, '[REDACTED]');
    return result;
  }

  LogLevel _parseLevel(String? name, {required LogLevel fallback}) {
    for (final level in LogLevel.values) {
      if (level.name == name) {
        return level;
      }
    }
    return fallback;
  }

  Set<LogCategory> _parseCategories(List<String>? names) {
    if (names == null || names.isEmpty) {
      return const LogConfig.defaults().enabledCategories;
    }

    final categories = <LogCategory>{};
    for (final name in names) {
      for (final category in LogCategory.values) {
        if (category.name == name) {
          categories.add(category);
        }
      }
    }
    return categories.isEmpty
        ? const LogConfig.defaults().enabledCategories
        : categories;
  }

  Future<void> _appendToFile(LogEntry entry) async {
    final dir = _logDir;
    if (dir == null) return;

    try {
      final file = _logFileForDate(entry.timestamp);
      await file.writeAsString(
        '${entry.formatted}\n',
        mode: FileMode.append,
        flush: false,
      );
    } catch (_) {
      // Non-blocking - swallow file write failures.
    }
  }

  File _logFileForDate(DateTime date) {
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return File('${_logDir!.path}/app_$stamp.log');
  }

  Future<void> _cleanupOldLogs() async {
    final dir = _logDir;
    if (dir == null) return;

    final cutoff = DateTime.now().subtract(
      const Duration(days: _retentionDays),
    );

    try {
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        final name = file.uri.pathSegments.last;
        final match = RegExp(r'app_(\d{8})\.log').firstMatch(name);
        if (match == null) continue;

        final dateStr = match.group(1)!;
        final year = int.tryParse(dateStr.substring(0, 4));
        final month = int.tryParse(dateStr.substring(4, 6));
        final day = int.tryParse(dateStr.substring(6, 8));
        if (year == null || month == null || day == null) continue;

        final fileDate = DateTime(year, month, day);
        if (fileDate.isBefore(cutoff)) {
          await file.delete();
        }
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  @visibleForTesting
  void debugReset() {
    _buffer.clear();
    loggingEnabled.value = true;
    config.value = const LogConfig.defaults();
    _logDir = null;
    _prefs = null;
    _initialized = false;
  }
}
