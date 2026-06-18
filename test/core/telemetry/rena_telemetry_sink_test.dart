import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/telemetry/rena_telemetry_sink.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tracks usage events through RTK with original property values', () {
    final client = _FakeRenaTelemetryClient();
    final sink = RenaTelemetrySink(client: client);
    final longRankType =
        'rtk-keeps-this-value-because-legacy-parameter-limits-are-gone';

    sink.track(
      TelemetryEvents.settingsSnapshot,
      properties: {
        TelemetryProperties.ignoreAI: true,
        TelemetryProperties.enabledHomeModules: ['ranking', 'recently_updated'],
        TelemetryProperties.homeRankType: longRankType,
      },
    );

    expect(client.events.single.name, TelemetryEvents.settingsSnapshot);
    expect(client.events.single.properties, {
      TelemetryProperties.ignoreAI: true,
      TelemetryProperties.enabledHomeModules: ['ranking', 'recently_updated'],
      TelemetryProperties.homeRankType: longRankType,
    });
  });

  test('tracks screen views as RTK events with screen dimensions', () {
    final client = _FakeRenaTelemetryClient();
    final sink = RenaTelemetrySink(client: client);

    sink.trackScreenView(
      TelemetryScreens.shelf,
      screenClass: 'MainTab',
      properties: {TelemetryProperties.tab: TelemetryTabs.shelf},
    );

    expect(client.events.single.name, 'screen_view');
    expect(client.events.single.properties, {
      TelemetryProperties.tab: TelemetryTabs.shelf,
      TelemetryProperties.screenName: TelemetryScreens.shelf,
      'screen_class': 'MainTab',
    });
  });

  test('records breadcrumbs and errors through RTK', () {
    final client = _FakeRenaTelemetryClient();
    final sink = RenaTelemetrySink(client: client);
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

    expect(client.breadcrumbs.single.name, 'foreground_started');
    expect(client.breadcrumbs.single.properties, {
      TelemetryProperties.tab: TelemetryTabs.home,
    });
    expect(client.errors.single.error.toString(), contains('safe error'));
    expect(client.errors.single.stackTrace, stackTrace);
    expect(client.errors.single.properties, {
      TelemetryProperties.module: 'sync',
      TelemetryProperties.source: 'invoke',
    });
  });

  test('flush delegates to RTK', () async {
    final client = _FakeRenaTelemetryClient();
    final sink = RenaTelemetrySink(client: client);

    await sink.flush();

    expect(client.flushCount, 1);
  });

  test('sets build metadata as RTK super properties', () {
    final client = _FakeRenaTelemetryClient();
    final sink = RenaTelemetrySink(client: client);

    sink.setBuildMetadata(buildChannel: 'pr', buildLabel: 'PR #123');

    expect(client.superProperties, {
      TelemetryProperties.buildChannel: 'pr',
      TelemetryProperties.buildLabel: 'PR #123',
    });
  });

  test('collection toggles do not opt out of RTK usage telemetry', () async {
    final client = _FakeRenaTelemetryClient();
    final sink = RenaTelemetrySink(client: client);

    await sink.setCollectionEnabled(
      analyticsEnabled: false,
      diagnosticsEnabled: false,
    );
    sink.track(TelemetryEvents.tabClicked);

    expect(client.events.single.name, TelemetryEvents.tabClicked);
    expect(client.clearQueuedTelemetryCount, 0);
  });

  test(
    'diagnostics opt-out clears persisted RTK errors while preserving events',
    () async {
      SharedPreferences.setMockInitialValues({
        'flutter.rena_rtk.queue': [
          _queuedRow({
            'type': 'event',
            'name': 'settings_snapshot',
            'timestamp': '2026-06-18T00:00:00.000Z',
            'properties': {'source': 'test'},
          }),
          _queuedRow({
            'type': 'error',
            'error_type': 'StateError',
            'message': 'safe error',
            'timestamp': '2026-06-18T00:00:01.000Z',
            'properties': {'module': 'sync'},
            'breadcrumbs': [],
          }),
        ],
      });
      final client = _FakeRenaTelemetryClient();
      final sink = RenaTelemetrySink(client: client);

      await sink.setCollectionEnabled(
        analyticsEnabled: true,
        diagnosticsEnabled: false,
      );

      final prefs = await SharedPreferences.getInstance();
      final rows = prefs.getStringList('rena_rtk.queue')!;
      expect(rows, hasLength(1));
      expect(jsonDecode(rows.single), {
        'item': {
          'type': 'event',
          'name': 'settings_snapshot',
          'timestamp': '2026-06-18T00:00:00.000Z',
          'properties': {'source': 'test'},
        },
        'attempt_count': 0,
      });

      sink.addBreadcrumb('foreground_started');
      sink.captureError(StateError('safe error'));

      expect(client.breadcrumbs, isEmpty);
      expect(client.errors, isEmpty);
      expect(client.clearQueuedTelemetryCount, 0);
    },
  );

  test(
    'diagnostics opt-out clears active RTK queue after capturing an error',
    () async {
      final client = _FakeRenaTelemetryClient();
      final sink = RenaTelemetrySink(client: client);

      sink.captureError(StateError('safe error'));
      await sink.setCollectionEnabled(
        analyticsEnabled: true,
        diagnosticsEnabled: false,
      );

      expect(client.errors, hasLength(1));
      expect(client.clearQueuedTelemetryCount, 1);
    },
  );
}

String _queuedRow(Map<String, Object?> item) {
  return jsonEncode({'item': item, 'attempt_count': 0});
}

class _FakeRenaTelemetryClient implements RenaTelemetryClient {
  final events = <_RecordedEvent>[];
  final breadcrumbs = <_RecordedEvent>[];
  final errors = <_RecordedError>[];
  Map<String, Object?> superProperties = {};
  int flushCount = 0;
  int clearQueuedTelemetryCount = 0;

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {
    events.add(_RecordedEvent(name, properties));
  }

  @override
  void addBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {
    breadcrumbs.add(_RecordedEvent(name, properties));
  }

  @override
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  }) {
    errors.add(_RecordedError(error, stackTrace, properties));
  }

  @override
  Future<void> flush() async {
    flushCount++;
  }

  @override
  void setSuperProperties(Map<String, Object?> properties) {
    superProperties = properties;
  }

  @override
  Future<void> clearQueuedTelemetry() async {
    clearQueuedTelemetryCount++;
  }
}

class _RecordedEvent {
  const _RecordedEvent(this.name, this.properties);

  final String name;
  final Map<String, Object?> properties;
}

class _RecordedError {
  const _RecordedError(this.error, this.stackTrace, this.properties);

  final Object error;
  final StackTrace? stackTrace;
  final Map<String, Object?> properties;
}
