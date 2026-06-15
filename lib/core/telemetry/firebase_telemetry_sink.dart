import 'dart:async';

import 'package:logging/logging.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';

abstract interface class FirebaseAnalyticsTelemetryClient {
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  });

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  });

  Future<void> setAnalyticsCollectionEnabled(bool enabled);

  Future<void> setDefaultEventParameters(Map<String, Object?>? parameters);
}

abstract interface class FirebaseCrashlyticsTelemetryClient {
  Future<void> log(String message);

  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    Iterable<Object> information = const [],
    bool fatal = false,
  });

  Future<void> sendUnsentReports();

  Future<void> setCrashlyticsCollectionEnabled(bool enabled);

  Future<void> setCustomKey(String key, Object value);
}

class FirebaseTelemetrySink
    implements TelemetrySink, TelemetryCollectionConfigurable {
  FirebaseTelemetrySink({required this.analytics, required this.crashlytics});

  static final Logger _logger = Logger('FirebaseTelemetrySink');

  final FirebaseAnalyticsTelemetryClient analytics;
  final FirebaseCrashlyticsTelemetryClient crashlytics;
  bool _diagnosticsCollectionEnabled = false;

  static const String _screenViewEventName = 'screen_view';
  static const String _firebaseScreenParameter = 'firebase_screen';
  static const String _firebaseScreenClassParameter = 'firebase_screen_class';
  static const int _maxAnalyticsStringLength = 100;
  static const int _maxCrashlyticsLogLength = 1000;

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {
    _send(
      analytics.logEvent(
        name: name,
        parameters: _analyticsParameters(properties),
      ),
    );
  }

  @override
  void trackScreenView(
    String screenName, {
    String? screenClass,
    Map<String, Object?> properties = const {},
  }) {
    _send(
      analytics.logEvent(
        name: _screenViewEventName,
        parameters: _screenViewParameters(
          screenName: screenName,
          screenClass: screenClass,
          properties: properties,
        ),
      ),
    );
  }

  @override
  void addBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {
    _send(crashlytics.log(_crashlyticsMessage(name, properties)));
  }

  @override
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  }) {
    _send(
      crashlytics.recordError(
        error,
        stackTrace,
        information: _crashlyticsInformation(properties),
        fatal: false,
      ),
    );
  }

  @override
  Future<void> flush() {
    if (!_diagnosticsCollectionEnabled) {
      return Future<void>.value();
    }
    return crashlytics.sendUnsentReports();
  }

  void setBuildMetadata({
    required String buildChannel,
    required String buildLabel,
  }) {
    final parameters = <String, Object?>{
      TelemetryProperties.buildChannel: _analyticsValue(buildChannel),
      TelemetryProperties.buildLabel: _analyticsValue(buildLabel),
    };
    _send(analytics.setDefaultEventParameters(parameters));
    _send(
      crashlytics.setCustomKey(TelemetryProperties.buildChannel, buildChannel),
    );
    _send(crashlytics.setCustomKey(TelemetryProperties.buildLabel, buildLabel));
  }

  @override
  void setCollectionEnabled({
    required bool analyticsEnabled,
    required bool diagnosticsEnabled,
  }) {
    _diagnosticsCollectionEnabled = diagnosticsEnabled;
    _send(analytics.setAnalyticsCollectionEnabled(analyticsEnabled));
    _send(crashlytics.setCrashlyticsCollectionEnabled(diagnosticsEnabled));
  }

  void _send(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        _logger.fine('Firebase telemetry call failed', error, stackTrace);
      }),
    );
  }

  Map<String, Object>? _analyticsParameters(Map<String, Object?> properties) {
    final parameters = <String, Object>{};
    for (final entry in properties.entries.take(25)) {
      final value = _analyticsValue(entry.value);
      if (value != null) {
        parameters[entry.key] = value;
      }
    }
    return parameters.isEmpty ? null : parameters;
  }

  Map<String, Object> _screenViewParameters({
    required String screenName,
    required String? screenClass,
    required Map<String, Object?> properties,
  }) {
    return {
      ...?_analyticsParameters(properties),
      _firebaseScreenParameter: _analyticsString(screenName),
      if (screenClass != null)
        _firebaseScreenClassParameter: _analyticsString(screenClass),
    };
  }

  Object? _analyticsValue(Object? value) {
    return switch (value) {
      null => null,
      bool() => value ? 1 : 0,
      int() => value,
      double() => value,
      String() => _limit(value, _maxAnalyticsStringLength),
      Iterable<Object?>() => _limit(
        value
            .map(_analyticsListValue)
            .where((item) => item.isNotEmpty)
            .join(','),
        _maxAnalyticsStringLength,
      ),
      _ => null,
    };
  }

  String _analyticsString(String value) {
    return value.length <= _maxAnalyticsStringLength
        ? value
        : value.substring(0, _maxAnalyticsStringLength);
  }

  String _analyticsListValue(Object? value) {
    return switch (value) {
      null => '',
      bool() => value ? '1' : '0',
      num() => value.toString(),
      String() => value,
      _ => '',
    };
  }

  String _crashlyticsMessage(String name, Map<String, Object?> properties) {
    final parts = <String>[name, ..._crashlyticsInformation(properties)];
    return _limit(parts.join(' '), _maxCrashlyticsLogLength);
  }

  List<String> _crashlyticsInformation(Map<String, Object?> properties) {
    final information = <String>[];
    for (final entry in properties.entries) {
      final value = _crashlyticsValue(entry.value);
      if (value.isNotEmpty) {
        information.add('${entry.key}=$value');
      }
    }
    return information;
  }

  String _crashlyticsValue(Object? value) {
    return switch (value) {
      null => '',
      bool() => value.toString(),
      num() => value.toString(),
      String() => value,
      Iterable<Object?>() => value
          .map(_crashlyticsValue)
          .where((item) => item.isNotEmpty)
          .join(','),
      _ => '',
    };
  }

  String _limit(String value, int maxLength) {
    return value.length <= maxLength ? value : value.substring(0, maxLength);
  }
}
