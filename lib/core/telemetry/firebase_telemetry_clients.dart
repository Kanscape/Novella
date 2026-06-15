import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:novella/core/telemetry/firebase_telemetry_sink.dart';

class FirebaseAnalyticsTelemetryAdapter
    implements FirebaseAnalyticsTelemetryClient {
  const FirebaseAnalyticsTelemetryAdapter(this.analytics);

  final FirebaseAnalytics analytics;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) {
    return analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) {
    return analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    );
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) {
    return analytics.setAnalyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> setDefaultEventParameters(Map<String, Object?>? parameters) {
    return analytics.setDefaultEventParameters(parameters);
  }
}

class FirebaseCrashlyticsTelemetryAdapter
    implements FirebaseCrashlyticsTelemetryClient {
  const FirebaseCrashlyticsTelemetryAdapter(this.crashlytics);

  final FirebaseCrashlytics crashlytics;

  @override
  Future<void> log(String message) {
    return crashlytics.log(message);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    Iterable<Object> information = const [],
    bool fatal = false,
  }) {
    return crashlytics.recordError(
      error,
      stackTrace,
      information: information,
      fatal: fatal,
      printDetails: false,
    );
  }

  @override
  Future<void> sendUnsentReports() {
    return crashlytics.sendUnsentReports();
  }

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) {
    return crashlytics.setCrashlyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> setCustomKey(String key, Object value) {
    return crashlytics.setCustomKey(key, value);
  }
}
