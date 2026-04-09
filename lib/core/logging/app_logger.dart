import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Log severity levels.
enum LogLevel { debug, info, error }

/// A single log entry.
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String message;

  String get formatted {
    final ts = timestamp.toIso8601String();
    final tag = level.name.toUpperCase();
    return '[$ts] [$tag] $message';
  }

  @override
  String toString() => formatted;
}

/// Centralized logging system with PII scrubbing, file rotation, and ring
/// buffer. All heavy I/O is compile-time gated behind [kDebugMode].
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const int _bufferCapacity = 500;
  static const int _retentionDays = 3;
  static const String _prefsKey = 'app_logger_enabled';

  // ---------------------------------------------------------------------------
  // PII scrubbing patterns
  // ---------------------------------------------------------------------------

  static final RegExp _studentIdPattern = RegExp(r'\d{10,12}');
  static final RegExp _mmPattern = RegExp(r'mm=[^\s&;]+');
  static final RegExp _passwordPattern = RegExp(r'password=[^\s&;]+');
  static final RegExp _sessionIdPattern = RegExp(r'JSESSIONID=[^\s;]+');
  static final RegExp _phonePattern = RegExp(r'1[3-9]\d{9}');

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final ListQueue<LogEntry> _buffer = ListQueue<LogEntry>(_bufferCapacity);

  /// Notifies listeners when logging is toggled.
  final ValueNotifier<bool> loggingEnabled = ValueNotifier<bool>(true);

  Directory? _logDir;
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Call once at app startup, after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    loggingEnabled.value = prefs.getBool(_prefsKey) ?? true;

    if (kDebugMode) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _logDir = Directory('${appDir.path}/logs');
        if (!_logDir!.existsSync()) {
          _logDir!.createSync(recursive: true);
        }
        await _cleanupOldLogs();
      } catch (_) {
        // File system unavailable (e.g. tests) — silently degrade.
      }
    }
  }

  /// Toggle persistent logging preference.
  Future<void> setEnabled(bool value) async {
    loggingEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  void debug(String message) => addEntry(LogLevel.debug, message);
  void info(String message) => addEntry(LogLevel.info, message);
  void error(String message) => addEntry(LogLevel.error, message);

  /// Read-only view of the in-memory ring buffer.
  List<LogEntry> get entries => List<LogEntry>.unmodifiable(_buffer.toList());

  /// Core logging method. Checks [kDebugMode] compile-time gate, scrubs PII,
  /// writes to both ring buffer and log file.
  void addEntry(LogLevel level, String message) {
    if (!kDebugMode) return;
    if (!loggingEnabled.value) return;

    final scrubbed = _scrub(message);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: scrubbed,
    );

    // Ring buffer eviction.
    if (_buffer.length >= _bufferCapacity) {
      _buffer.removeFirst();
    }
    _buffer.addLast(entry);

    // Console output.
    debugPrint(entry.formatted);

    // Fire-and-forget file append.
    _appendToFile(entry);
  }

  // ---------------------------------------------------------------------------
  // PII scrubbing
  // ---------------------------------------------------------------------------

  /// Replace PII tokens with [REDACTED].
  String _scrub(String input) {
    var result = input;
    result = result.replaceAll(_sessionIdPattern, 'JSESSIONID=[REDACTED]');
    result = result.replaceAll(_passwordPattern, 'password=[REDACTED]');
    result = result.replaceAll(_mmPattern, 'mm=[REDACTED]');
    result = result.replaceAll(_phonePattern, '[REDACTED]');
    result = result.replaceAll(_studentIdPattern, '[REDACTED]');
    return result;
  }

  // ---------------------------------------------------------------------------
  // File I/O (debug-only)
  // ---------------------------------------------------------------------------

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
      // Non-blocking — swallow file write failures.
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
}
