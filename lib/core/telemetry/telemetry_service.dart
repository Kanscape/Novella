import 'dart:async';
import 'dart:math' show Random;

import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_sanitizer.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';

class TelemetryService {
  TelemetryService({
    TelemetrySink? sink,
    bool diagnosticsEnabled = true,
    TelemetryRemotePolicy remotePolicy = const TelemetryRemotePolicy(),
    DateTime Function()? now,
    double Function()? diagnosticSample,
  }) : _sink = sink ?? const NoopTelemetrySink(),
       _diagnosticsEnabled = diagnosticsEnabled,
       _remotePolicy = remotePolicy,
       _now = now ?? DateTime.now,
       _diagnosticSample = diagnosticSample ?? Random().nextDouble {
    _applyCollectionSettings();
  }

  static final TelemetryService instance = TelemetryService();

  TelemetrySink _sink;
  bool _diagnosticsEnabled;
  TelemetryRemotePolicy _remotePolicy;
  DateTime Function() _now;
  double Function() _diagnosticSample;
  final _pendingUsageCalls = <void Function(TelemetrySink sink)>[];
  bool _foregroundActive = false;
  String _currentTab = TelemetryTabs.home;
  bool _dayTypeRecorded = false;

  void configure({
    TelemetrySink? sink,
    bool? diagnosticsEnabled,
    TelemetryRemotePolicy? remotePolicy,
    DateTime Function()? now,
    double Function()? diagnosticSample,
  }) {
    if (sink != null) {
      _sink = sink;
    }
    if (diagnosticsEnabled != null) {
      _diagnosticsEnabled = diagnosticsEnabled;
    }
    if (remotePolicy != null) {
      _remotePolicy = remotePolicy;
    }
    if (now != null) {
      _now = now;
    }
    if (diagnosticSample != null) {
      _diagnosticSample = diagnosticSample;
    }
    _applyCollectionSettings();
    _syncPendingUsageCalls();
  }

  void setDiagnosticsEnabled(bool enabled) {
    _diagnosticsEnabled = enabled;
    _applyCollectionSettings();
  }

  void setRemotePolicy(TelemetryRemotePolicy policy) {
    _remotePolicy = policy;
    _applyCollectionSettings();
    _syncPendingUsageCalls();
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
    if (_foregroundActive) {
      return;
    }
    final tab = startupTab ?? _currentTab;
    _currentTab = tab;
    _foregroundActive = true;
    addDiagnosticBreadcrumb(
      'foreground_started',
      properties: {TelemetryProperties.tab: tab},
    );
  }

  void endForeground() {
    if (!_foregroundActive) {
      return;
    }
    _foregroundActive = false;
  }

  void track(String name, {Map<String, Object?> properties = const {}}) {
    final sanitizedProperties = TelemetrySanitizer.usageProperties(properties);
    _sendOrQueueUsage(
      (sink) => sink.track(name, properties: sanitizedProperties),
    );
  }

  void trackScreenView(
    String screenName, {
    String? screenClass,
    Map<String, Object?> properties = const {},
  }) {
    final sanitizedProperties = TelemetrySanitizer.usageProperties(properties);
    _sendOrQueueUsage(
      (sink) => sink.trackScreenView(
        screenName,
        screenClass: screenClass,
        properties: sanitizedProperties,
      ),
    );
    addDiagnosticBreadcrumb(
      'screen_view',
      properties: {TelemetryProperties.screenName: screenName, ...properties},
    );
  }

  void addDiagnosticBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {
    if (!_diagnosticsEnabled || !_remotePolicy.diagnosticsEnabled) {
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
    if (!_remotePolicy.allowsDiagnosticError(
      localDiagnosticsEnabled: _diagnosticsEnabled,
      reportable: reportable,
      sampleValue: _diagnosticSample(),
    )) {
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

  Future<void> flush() {
    if (!_effectiveDiagnosticsEnabled) {
      return Future<void>.value();
    }
    return _sink.flush();
  }

  static String dayType(DateTime time) {
    final local = time.toLocal();
    return local.weekday == DateTime.saturday ||
            local.weekday == DateTime.sunday
        ? TelemetryDayTypes.weekend
        : TelemetryDayTypes.weekday;
  }

  void _applyCollectionSettings() {
    final sink = _sink;
    if (sink is! TelemetryCollectionConfigurable) {
      return;
    }
    final configurableSink = sink as TelemetryCollectionConfigurable;
    configurableSink.setCollectionEnabled(
      analyticsEnabled: _remotePolicy.analyticsEnabled,
      diagnosticsEnabled: _effectiveDiagnosticsEnabled,
    );
  }

  bool get _effectiveDiagnosticsEnabled =>
      _diagnosticsEnabled && _remotePolicy.diagnosticsEnabled;

  void _sendOrQueueUsage(void Function(TelemetrySink sink) send) {
    if (_remotePolicy.analyticsEnabled) {
      send(_sink);
      return;
    }
    if (!_remotePolicy.usageCollectionPending) {
      return;
    }
    if (_pendingUsageCalls.length >= 64) {
      _pendingUsageCalls.removeAt(0);
    }
    _pendingUsageCalls.add(send);
  }

  void _syncPendingUsageCalls() {
    if (_remotePolicy.analyticsEnabled) {
      final calls = List<void Function(TelemetrySink sink)>.from(
        _pendingUsageCalls,
      );
      _pendingUsageCalls.clear();
      for (final call in calls) {
        call(_sink);
      }
      return;
    }
    if (!_remotePolicy.usageCollectionPending) {
      _pendingUsageCalls.clear();
    }
  }
}

abstract interface class TelemetryCollectionConfigurable {
  void setCollectionEnabled({
    required bool analyticsEnabled,
    required bool diagnosticsEnabled,
  });
}

class TelemetryRemotePolicy {
  const TelemetryRemotePolicy({
    this.analyticsEnabled = true,
    this.diagnosticsEnabled = true,
    this.nonFatalErrorSampleRate = 1.0,
    this.usageCollectionPending = false,
  });

  final bool analyticsEnabled;
  final bool diagnosticsEnabled;
  final double nonFatalErrorSampleRate;
  final bool usageCollectionPending;

  bool allowsDiagnosticError({
    required bool localDiagnosticsEnabled,
    required bool reportable,
    required double sampleValue,
  }) {
    if (!localDiagnosticsEnabled || !diagnosticsEnabled || !reportable) {
      return false;
    }
    final rate = nonFatalErrorSampleRate.clamp(0.0, 1.0);
    return sampleValue.clamp(0.0, 1.0) < rate;
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
