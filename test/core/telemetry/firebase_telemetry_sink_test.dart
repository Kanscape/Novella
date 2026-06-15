import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/telemetry/firebase_telemetry_sink.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';

void main() {
  test('tracks analytics events with Firebase-compatible parameters', () {
    final analytics = _FakeAnalyticsClient();
    final sink = FirebaseTelemetrySink(
      analytics: analytics,
      crashlytics: _FakeCrashlyticsClient(),
    );
    const longRankType =
        'weekly-with-a-very-long-string-that-needs-to-be-truncated-before-'
        'firebase-receives-it-because-analytics-parameters-have-limits';

    sink.track(
      TelemetryEvents.settingsSnapshot,
      properties: {
        TelemetryProperties.ignoreAI: true,
        TelemetryProperties.enabledHomeModules: ['ranking', 'recently_updated'],
        TelemetryProperties.homeRankType: longRankType,
        'ignored_null': null,
      },
    );

    expect(analytics.events, hasLength(1));
    expect(analytics.events.single.name, TelemetryEvents.settingsSnapshot);
    expect(analytics.events.single.parameters, {
      TelemetryProperties.ignoreAI: 1,
      TelemetryProperties.enabledHomeModules: 'ranking,recently_updated',
      TelemetryProperties.homeRankType: longRankType.substring(0, 100),
    });
  });

  test('tracks screen views with Firebase screen view API', () {
    final analytics = _FakeAnalyticsClient();
    final sink = FirebaseTelemetrySink(
      analytics: analytics,
      crashlytics: _FakeCrashlyticsClient(),
    );

    sink.trackScreenView(
      TelemetryScreens.shelf,
      screenClass: 'MainTab',
      properties: {TelemetryProperties.tab: TelemetryTabs.shelf},
    );

    expect(analytics.events, isEmpty);
    expect(analytics.screenViews, [
      const _AnalyticsScreenView(
        screenName: TelemetryScreens.shelf,
        screenClass: 'MainTab',
        parameters: {TelemetryProperties.tab: TelemetryTabs.shelf},
      ),
    ]);
  });

  test('records breadcrumbs and errors in Crashlytics format', () {
    final crashlytics = _FakeCrashlyticsClient();
    final sink = FirebaseTelemetrySink(
      analytics: _FakeAnalyticsClient(),
      crashlytics: crashlytics,
    );
    final stackTrace = StackTrace.current;

    sink.addBreadcrumb(
      'foreground_started',
      properties: {TelemetryProperties.tab: TelemetryTabs.home},
    );
    sink.captureError(
      StateError('safe error'),
      stackTrace: stackTrace,
      properties: {
        TelemetryProperties.module: 'sync',
        TelemetryProperties.source: 'invoke',
      },
    );

    expect(crashlytics.logs, ['foreground_started tab=home']);
    expect(crashlytics.errors, hasLength(1));
    expect(crashlytics.errors.single.error.toString(), contains('safe error'));
    expect(crashlytics.errors.single.stackTrace, stackTrace);
    expect(crashlytics.errors.single.information, [
      'module=sync',
      'source=invoke',
    ]);
  });

  test(
    'skips flushing unsent reports while diagnostics collection is off',
    () async {
      final analytics = _FakeAnalyticsClient();
      final crashlytics = _FakeCrashlyticsClient();
      final sink = FirebaseTelemetrySink(
        analytics: analytics,
        crashlytics: crashlytics,
      );

      sink.setCollectionEnabled(
        analyticsEnabled: false,
        diagnosticsEnabled: false,
      );
      await sink.flush();

      expect(analytics.collectionEnabled, false);
      expect(crashlytics.collectionEnabled, false);
      expect(crashlytics.sendUnsentReportsCount, 0);

      sink.setCollectionEnabled(
        analyticsEnabled: false,
        diagnosticsEnabled: true,
      );
      await sink.flush();

      expect(crashlytics.sendUnsentReportsCount, 1);
    },
  );

  test('sets build metadata for Firebase filtering', () {
    final analytics = _FakeAnalyticsClient();
    final crashlytics = _FakeCrashlyticsClient();
    final sink = FirebaseTelemetrySink(
      analytics: analytics,
      crashlytics: crashlytics,
    );

    sink.setBuildMetadata(buildChannel: 'pr', buildLabel: 'PR #123');

    expect(analytics.defaultEventParameters, {
      TelemetryProperties.buildChannel: 'pr',
      TelemetryProperties.buildLabel: 'PR #123',
    });
    expect(crashlytics.customKeys, {
      TelemetryProperties.buildChannel: 'pr',
      TelemetryProperties.buildLabel: 'PR #123',
    });
  });
}

class _FakeAnalyticsClient implements FirebaseAnalyticsTelemetryClient {
  final events = <_AnalyticsEvent>[];
  final screenViews = <_AnalyticsScreenView>[];
  bool? collectionEnabled;
  Map<String, Object?>? defaultEventParameters;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add(_AnalyticsEvent(name, parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    screenViews.add(
      _AnalyticsScreenView(
        screenName: screenName,
        screenClass: screenClass,
        parameters: parameters,
      ),
    );
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> setDefaultEventParameters(
    Map<String, Object?>? parameters,
  ) async {
    defaultEventParameters = parameters;
  }
}

class _FakeCrashlyticsClient implements FirebaseCrashlyticsTelemetryClient {
  final logs = <String>[];
  final errors = <_CrashlyticsError>[];
  final customKeys = <String, Object>{};
  bool? collectionEnabled;
  int sendUnsentReportsCount = 0;

  @override
  Future<void> log(String message) async {
    logs.add(message);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    Iterable<Object> information = const [],
    bool fatal = false,
  }) async {
    errors.add(
      _CrashlyticsError(
        error: error,
        stackTrace: stackTrace,
        information: List<Object>.from(information),
        fatal: fatal,
      ),
    );
  }

  @override
  Future<void> sendUnsentReports() async {
    sendUnsentReportsCount++;
  }

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> setCustomKey(String key, Object value) async {
    customKeys[key] = value;
  }
}

class _AnalyticsEvent {
  const _AnalyticsEvent(this.name, this.parameters);

  final String name;
  final Map<String, Object>? parameters;
}

class _AnalyticsScreenView {
  const _AnalyticsScreenView({
    required this.screenName,
    required this.screenClass,
    required this.parameters,
  });

  final String screenName;
  final String? screenClass;
  final Map<String, Object>? parameters;

  @override
  bool operator ==(Object other) {
    return other is _AnalyticsScreenView &&
        other.screenName == screenName &&
        other.screenClass == screenClass &&
        _mapEquals(other.parameters, parameters);
  }

  @override
  int get hashCode => Object.hash(screenName, screenClass, parameters);

  @override
  String toString() {
    return 'AnalyticsScreenView('
        'screenName: $screenName, '
        'screenClass: $screenClass, '
        'parameters: $parameters)';
  }
}

class _CrashlyticsError {
  const _CrashlyticsError({
    required this.error,
    required this.stackTrace,
    required this.information,
    required this.fatal,
  });

  final Object error;
  final StackTrace? stackTrace;
  final List<Object> information;
  final bool fatal;
}

bool _mapEquals(Map<String, Object>? left, Map<String, Object>? right) {
  if (left == null || right == null) {
    return left == right;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final entry in left.entries) {
    if (!right.containsKey(entry.key) || right[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
