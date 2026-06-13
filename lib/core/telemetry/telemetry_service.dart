import 'dart:async';

import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_sanitizer.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';

class TelemetryService {
  TelemetryService({
    TelemetrySink? sink,
    bool diagnosticsEnabled = true,
    DateTime Function()? now,
  }) : _sink = sink ?? const NoopTelemetrySink(),
       _diagnosticsEnabled = diagnosticsEnabled,
       _now = now ?? DateTime.now;

  static final TelemetryService instance = TelemetryService();

  TelemetrySink _sink;
  bool _diagnosticsEnabled;
  DateTime Function() _now;
  DateTime? _foregroundStartedAt;
  String? _foregroundStartupTab;
  String _currentTab = TelemetryTabs.home;
  bool _dayTypeRecorded = false;

  void configure({
    TelemetrySink? sink,
    bool? diagnosticsEnabled,
    DateTime Function()? now,
  }) {
    if (sink != null) {
      _sink = sink;
    }
    if (diagnosticsEnabled != null) {
      _diagnosticsEnabled = diagnosticsEnabled;
    }
    if (now != null) {
      _now = now;
    }
  }

  void setDiagnosticsEnabled(bool enabled) {
    _diagnosticsEnabled = enabled;
  }

  void setCurrentTab(String tab) {
    _currentTab = tab;
  }

  void recordDayType() {
    if (_dayTypeRecorded) {
      return;
    }
    _dayTypeRecorded = true;
    final now = _now();
    track(
      TelemetryEvents.appDayType,
      properties: {TelemetryProperties.dayType: dayType(now)},
    );
  }

  void startForeground({String? startupTab}) {
    if (_foregroundStartedAt != null) {
      return;
    }
    final tab = startupTab ?? _currentTab;
    _currentTab = tab;
    _foregroundStartupTab = tab;
    _foregroundStartedAt = _now();
    addDiagnosticBreadcrumb(
      'foreground_started',
      properties: {TelemetryProperties.tab: tab},
    );
  }

  void endForeground({required String endedBy}) {
    final startedAt = _foregroundStartedAt;
    if (startedAt == null) {
      return;
    }
    _foregroundStartedAt = null;
    final startupTab = _foregroundStartupTab ?? _currentTab;
    _foregroundStartupTab = null;

    final endedAt = _now();
    var duration = endedAt.difference(startedAt);
    if (duration < const Duration(seconds: 3)) {
      return;
    }
    if (duration > const Duration(hours: 12)) {
      duration = const Duration(hours: 12);
    }

    track(
      TelemetryEvents.appSession,
      properties: {
        TelemetryProperties.sessionDurationBucket: durationBucket(duration),
        ..._timeProperties(endedAt),
        TelemetryProperties.startupTab: startupTab,
        TelemetryProperties.endedBy: endedBy,
      },
    );
  }

  void track(String name, {Map<String, Object?> properties = const {}}) {
    _sink.track(
      name,
      properties: TelemetrySanitizer.usageProperties(properties),
    );
  }

  void addDiagnosticBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {
    if (!_diagnosticsEnabled) {
      return;
    }
    _sink.addBreadcrumb(
      name,
      properties: TelemetrySanitizer.diagnosticProperties(properties),
    );
  }

  void captureError(
    Object error, {
    StackTrace? stackTrace,
    required String module,
    bool reportable = true,
    Map<String, Object?> properties = const {},
  }) {
    if (!_diagnosticsEnabled || !reportable) {
      return;
    }
    final sanitizedError = TelemetryCapturedError(
      originalType: error.runtimeType.toString(),
      message: TelemetrySanitizer.sanitizeMessage(error),
    );
    _sink.captureError(
      sanitizedError,
      stackTrace: TelemetrySanitizer.sanitizeStackTrace(stackTrace),
      properties: TelemetrySanitizer.diagnosticProperties({
        ...properties,
        TelemetryProperties.module: module,
      }),
    );
  }

  Future<void> flush() => _sink.flush();

  static String localDate(DateTime time) {
    final local = time.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static String dayType(DateTime time) {
    final local = time.toLocal();
    return local.weekday == DateTime.saturday ||
            local.weekday == DateTime.sunday
        ? TelemetryDayTypes.weekend
        : TelemetryDayTypes.weekday;
  }

  static String hourBucket(DateTime time) {
    final hour = time.toLocal().hour;
    if (hour < 6) {
      return '0-5';
    }
    if (hour < 12) {
      return '6-11';
    }
    if (hour < 18) {
      return '12-17';
    }
    return '18-23';
  }

  static String durationBucket(Duration duration) {
    if (duration < const Duration(seconds: 30)) {
      return '3-30s';
    }
    if (duration < const Duration(minutes: 2)) {
      return '30s-2m';
    }
    if (duration < const Duration(minutes: 10)) {
      return '2-10m';
    }
    if (duration < const Duration(minutes: 30)) {
      return '10-30m';
    }
    return '30m+';
  }

  Map<String, Object?> _timeProperties(DateTime time) {
    return {
      TelemetryProperties.localDate: localDate(time),
      TelemetryProperties.dayType: dayType(time),
      TelemetryProperties.localHourBucket: hourBucket(time),
    };
  }
}

class TelemetryCapturedError {
  const TelemetryCapturedError({
    required this.originalType,
    required this.message,
  });

  final String originalType;
  final String message;

  @override
  String toString() => '$originalType: $message';
}
