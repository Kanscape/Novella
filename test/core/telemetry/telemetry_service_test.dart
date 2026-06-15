import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_sanitizer.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('external link click event uses external link wording', () {
    expect(TelemetryEvents.externalLinkClicked, 'external_link_clicked');
  });

  test('usage events are sanitized and ignore diagnostics opt-out', () {
    final sink = _FakeTelemetrySink();
    final service = TelemetryService(
      sink: sink,
      diagnosticsEnabled: false,
      now: () => DateTime(2026, 6, 11, 21),
    );

    service.track(
      TelemetryEvents.tabClicked,
      properties: {
        TelemetryProperties.tab: TelemetryTabs.home,
        'book_id': 123,
        'title': 'private title',
        'url': 'https://example.com/book/123',
      },
    );
    service.addDiagnosticBreadcrumb(
      'sync_failed',
      properties: {TelemetryProperties.module: 'sync'},
    );
    service.captureError(
      StateError('secret token=abc https://example.com/private'),
      stackTrace: StackTrace.current,
      module: 'sync',
    );

    expect(sink.events, hasLength(1));
    expect(sink.events.single.name, TelemetryEvents.tabClicked);
    expect(sink.events.single.properties, {
      TelemetryProperties.tab: TelemetryTabs.home,
    });
    expect(sink.breadcrumbs, isEmpty);
    expect(sink.errors, isEmpty);
  });

  test(
    'remote policy can disable usage events without changing diagnostics',
    () {
      final sink = _FakeTelemetrySink();
      final service = TelemetryService(
        sink: sink,
        remotePolicy: const TelemetryRemotePolicy(analyticsEnabled: false),
      );

      service.track(
        TelemetryEvents.tabClicked,
        properties: {TelemetryProperties.tab: TelemetryTabs.home},
      );
      service.addDiagnosticBreadcrumb(
        'foreground_started',
        properties: {TelemetryProperties.tab: TelemetryTabs.home},
      );

      expect(sink.events, isEmpty);
      expect(sink.breadcrumbs, hasLength(1));
    },
  );

  test('screen views are usage analytics and respect remote policy', () {
    final sink = _FakeTelemetrySink();
    final service = TelemetryService(
      sink: sink,
      remotePolicy: const TelemetryRemotePolicy(analyticsEnabled: false),
    );

    service.trackScreenView(TelemetryScreens.home);

    expect(sink.screenViews, isEmpty);

    service.setRemotePolicy(const TelemetryRemotePolicy());
    service.trackScreenView(
      TelemetryScreens.search,
      screenClass: 'SearchPage',
      properties: {TelemetryProperties.source: TelemetryScreens.bookDetail},
    );

    expect(sink.screenViews, [
      const _RecordedScreenView(
        screenName: TelemetryScreens.search,
        screenClass: 'SearchPage',
        properties: {TelemetryProperties.source: TelemetryScreens.bookDetail},
      ),
    ]);
  });

  test('usage events wait for a pending analytics policy', () {
    final sink = _FakeTelemetrySink();
    final service = TelemetryService(
      sink: sink,
      remotePolicy: const TelemetryRemotePolicy(
        analyticsEnabled: false,
        usageCollectionPending: true,
      ),
      now: () => DateTime(2026, 6, 15, 8),
    );

    service.track(
      TelemetryEvents.settingsSnapshot,
      properties: {TelemetryProperties.ignoreAI: false},
    );
    service.recordDayType();
    service.trackScreenView(TelemetryScreens.home, screenClass: 'MainTab');

    expect(sink.events, isEmpty);
    expect(sink.screenViews, isEmpty);

    service.setRemotePolicy(const TelemetryRemotePolicy());
    service.recordDayType();

    expect(sink.events, hasLength(2));
    expect(sink.events[0].name, TelemetryEvents.settingsSnapshot);
    expect(sink.events[0].properties, {TelemetryProperties.ignoreAI: false});
    expect(sink.events[1].name, TelemetryEvents.appDayType);
    expect(sink.events[1].properties, {
      TelemetryProperties.dayType: TelemetryDayTypes.weekday,
    });
    expect(sink.screenViews, [
      const _RecordedScreenView(
        screenName: TelemetryScreens.home,
        screenClass: 'MainTab',
        properties: {},
      ),
    ]);
  });

  test('pending usage events are dropped when analytics stays disabled', () {
    final sink = _FakeTelemetrySink();
    final service = TelemetryService(
      sink: sink,
      remotePolicy: const TelemetryRemotePolicy(
        analyticsEnabled: false,
        usageCollectionPending: true,
      ),
    );

    service.track(TelemetryEvents.settingsSnapshot);
    service.setRemotePolicy(
      const TelemetryRemotePolicy(analyticsEnabled: false),
    );
    service.setRemotePolicy(const TelemetryRemotePolicy());

    expect(sink.events, isEmpty);
  });

  test(
    'screen views leave diagnostic breadcrumbs even when analytics is off',
    () {
      final sink = _FakeTelemetrySink();
      final service = TelemetryService(
        sink: sink,
        remotePolicy: const TelemetryRemotePolicy(
          analyticsEnabled: false,
          diagnosticsEnabled: true,
        ),
      );

      service.trackScreenView(
        TelemetryScreens.reader,
        screenClass: 'ReaderPagedPage',
        properties: {
          TelemetryProperties.readerViewMode: 'paged',
          'book_title': 'private title',
        },
      );

      expect(sink.screenViews, isEmpty);
      expect(sink.breadcrumbs, hasLength(1));
      expect(sink.breadcrumbs.single.name, 'screen_view');
      expect(sink.breadcrumbs.single.properties, {
        TelemetryProperties.screenName: TelemetryScreens.reader,
        TelemetryProperties.readerViewMode: 'paged',
      });
    },
  );

  test('manual screen taxonomy includes a single announcement screen', () {
    expect(TelemetryScreens.announcement, 'announcement');
  });

  test('remote policy and local setting both gate diagnostic errors', () {
    final sink = _FakeTelemetrySink();
    var sample = 0.4;
    final service = TelemetryService(
      sink: sink,
      diagnosticsEnabled: true,
      diagnosticSample: () => sample,
      remotePolicy: const TelemetryRemotePolicy(
        diagnosticsEnabled: true,
        nonFatalErrorSampleRate: 0.5,
      ),
    );

    service.captureError(StateError('first'), module: 'sync');
    sample = 0.6;
    service.captureError(StateError('second'), module: 'sync');
    service.setDiagnosticsEnabled(false);
    sample = 0.1;
    service.captureError(StateError('third'), module: 'sync');

    expect(sink.errors, hasLength(1));
    expect(sink.errors.single.error.toString(), contains('first'));
  });

  test('collection settings combine remote policy and local diagnostics', () {
    final sink = _ConfigurableTelemetrySink();
    final service = TelemetryService(
      sink: sink,
      diagnosticsEnabled: true,
      remotePolicy: const TelemetryRemotePolicy(
        analyticsEnabled: true,
        diagnosticsEnabled: true,
      ),
    );

    expect(sink.collectionSettings, [
      const _CollectionSettings(
        analyticsEnabled: true,
        diagnosticsEnabled: true,
      ),
    ]);

    service.setDiagnosticsEnabled(false);
    service.setRemotePolicy(
      const TelemetryRemotePolicy(
        analyticsEnabled: false,
        diagnosticsEnabled: true,
      ),
    );

    expect(sink.collectionSettings, [
      const _CollectionSettings(
        analyticsEnabled: true,
        diagnosticsEnabled: true,
      ),
      const _CollectionSettings(
        analyticsEnabled: true,
        diagnosticsEnabled: false,
      ),
      const _CollectionSettings(
        analyticsEnabled: false,
        diagnosticsEnabled: false,
      ),
    ]);
  });

  test('flush is skipped while diagnostics are disabled', () async {
    final sink = _FakeTelemetrySink();
    final service = TelemetryService(
      sink: sink,
      diagnosticsEnabled: true,
      remotePolicy: const TelemetryRemotePolicy(diagnosticsEnabled: true),
    );

    await service.flush();
    service.setDiagnosticsEnabled(false);
    await service.flush();
    service.setDiagnosticsEnabled(true);
    service.setRemotePolicy(
      const TelemetryRemotePolicy(diagnosticsEnabled: false),
    );
    await service.flush();

    expect(sink.flushCount, 1);
  });

  test('records day type separately because SDK records app launch', () {
    final sink = _FakeTelemetrySink();
    final service = TelemetryService(
      sink: sink,
      now: () => DateTime(2026, 6, 13, 20),
    );

    service.recordDayType();
    service.recordDayType();

    expect(sink.events, hasLength(1));
    expect(sink.events.single.name, TelemetryEvents.appDayType);
    expect(sink.events.single.properties, {
      TelemetryProperties.dayType: TelemetryDayTypes.weekend,
    });
    expect(
      sink.events.map((event) => event.name),
      isNot(contains('app_launch_count')),
    );
  });

  test(
    'records foreground session duration bucket and drops tiny sessions',
    () {
      final sink = _FakeTelemetrySink();
      var now = DateTime(2026, 6, 11, 9);
      final service = TelemetryService(sink: sink, now: () => now);

      service.startForeground(startupTab: TelemetryTabs.home);
      now = now.add(const Duration(seconds: 2));
      service.endForeground(endedBy: 'background');

      service.startForeground(startupTab: TelemetryTabs.shelf);
      now = now.add(const Duration(minutes: 5));
      service.endForeground(endedBy: 'background');

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, TelemetryEvents.appSession);
      expect(sink.events.single.properties, {
        TelemetryProperties.sessionDurationBucket: '2-10m',
        TelemetryProperties.localDate: '2026-06-11',
        TelemetryProperties.dayType: TelemetryDayTypes.weekday,
        TelemetryProperties.localHourBucket: '6-11',
        TelemetryProperties.startupTab: TelemetryTabs.shelf,
        TelemetryProperties.endedBy: 'background',
      });
    },
  );

  test('does not restart an active foreground session', () {
    final sink = _FakeTelemetrySink();
    var now = DateTime(2026, 6, 11, 9);
    final service = TelemetryService(sink: sink, now: () => now);

    service.startForeground(startupTab: TelemetryTabs.home);
    service.setCurrentTab(TelemetryTabs.shelf);
    now = now.add(const Duration(minutes: 1));
    service.startForeground();
    now = now.add(const Duration(minutes: 1));
    service.endForeground(endedBy: 'background');

    expect(sink.events, hasLength(1));
    expect(sink.events.single.properties, {
      TelemetryProperties.sessionDurationBucket: '2-10m',
      TelemetryProperties.localDate: '2026-06-11',
      TelemetryProperties.dayType: TelemetryDayTypes.weekday,
      TelemetryProperties.localHourBucket: '6-11',
      TelemetryProperties.startupTab: TelemetryTabs.home,
      TelemetryProperties.endedBy: 'background',
    });
  });

  test('sanitizes diagnostic strings before they can be sent', () {
    final message = TelemetrySanitizer.sanitizeMessage(
      'Failed token=abc at https://example.com/a /Users/me/file.dart '
      r'C:\Users\me\secret.txt monkey=value',
    );

    expect(message, contains('token=[redacted]'));
    expect(message, contains('[url]'));
    expect(message, contains('[path]'));
    expect(message, isNot(contains('/Users/me/file.dart')));
    expect(message, isNot(contains(r'C:\Users\me\secret.txt')));
    expect(message, contains('monkey=value'));
  });

  test('redacts common Linux and Android absolute paths', () {
    final message = TelemetrySanitizer.sanitizeMessage(
      'Failed at /home/alice/app/log.txt '
      'and /data/user/0/com.novella/cache/db.sqlite '
      'and /storage/emulated/0/Download/book.txt',
    );

    expect(message, contains('[path]'));
    expect(message, isNot(contains('/home/alice/app/log.txt')));
    expect(
      message,
      isNot(contains('/data/user/0/com.novella/cache/db.sqlite')),
    );
    expect(message, isNot(contains('/storage/emulated/0/Download/book.txt')));
  });

  test('redacts full authorization bearer values', () {
    final message = TelemetrySanitizer.sanitizeMessage(
      'Request failed Authorization: Bearer abc.def.ghi',
    );

    expect(message, contains('Authorization=[redacted]'));
    expect(message, isNot(contains('Bearer abc.def.ghi')));
    expect(message, isNot(contains('abc.def.ghi')));
  });

  test('redacts quoted JSON and map secret fields', () {
    final message = TelemetrySanitizer.sanitizeMessage(
      '{"refresh_token":"abc.def.ghi","password":"hunter2",'
      "'secret': 'value123', key: plain}",
    );

    expect(message, contains('"refresh_token"=[redacted]'));
    expect(message, contains('"password"=[redacted]'));
    expect(message, contains("'secret'=[redacted]"));
    expect(message, contains('key=[redacted]'));
    expect(message, isNot(contains('abc.def.ghi')));
    expect(message, isNot(contains('hunter2')));
    expect(message, isNot(contains('value123')));
    expect(message, isNot(contains('plain')));
  });

  test('redacts token fields with prefixes', () {
    final message = TelemetrySanitizer.sanitizeMessage(
      'access_token=abc.def github_access_token=ghi.jkl '
      '"github_refresh_token":"mno.pqr"',
    );

    expect(message, contains('access_token=[redacted]'));
    expect(message, contains('github_access_token=[redacted]'));
    expect(message, contains('"github_refresh_token"=[redacted]'));
    expect(message, isNot(contains('abc.def')));
    expect(message, isNot(contains('ghi.jkl')));
    expect(message, isNot(contains('mno.pqr')));
  });

  test('redacts camelCase and PascalCase token fields', () {
    final message = TelemetrySanitizer.sanitizeMessage(
      'refreshToken=abc.def RefreshToken=ghi.jkl '
      '"githubAccessToken":"mno.pqr" sessionToken: stu.vwx',
    );

    expect(message, contains('refreshToken=[redacted]'));
    expect(message, contains('RefreshToken=[redacted]'));
    expect(message, contains('"githubAccessToken"=[redacted]'));
    expect(message, contains('sessionToken=[redacted]'));
    expect(message, isNot(contains('abc.def')));
    expect(message, isNot(contains('ghi.jkl')));
    expect(message, isNot(contains('mno.pqr')));
    expect(message, isNot(contains('stu.vwx')));
  });

  test('preserves foreground session startup tab after tab changes', () {
    final sink = _FakeTelemetrySink();
    var now = DateTime(2026, 6, 11, 9);
    final service = TelemetryService(sink: sink, now: () => now);

    service.startForeground(startupTab: TelemetryTabs.home);
    service.setCurrentTab(TelemetryTabs.shelf);
    now = now.add(const Duration(minutes: 5));
    service.endForeground(endedBy: 'background');

    expect(sink.events, hasLength(1));
    expect(
      sink.events.single.properties[TelemetryProperties.startupTab],
      TelemetryTabs.home,
    );
  });
}

class _FakeTelemetrySink implements TelemetrySink {
  final events = <_RecordedEvent>[];
  final screenViews = <_RecordedScreenView>[];
  final breadcrumbs = <_RecordedEvent>[];
  final errors = <_RecordedError>[];
  int flushCount = 0;

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {
    events.add(_RecordedEvent(name, properties));
  }

  @override
  void trackScreenView(
    String screenName, {
    String? screenClass,
    Map<String, Object?> properties = const {},
  }) {
    screenViews.add(
      _RecordedScreenView(
        screenName: screenName,
        screenClass: screenClass,
        properties: properties,
      ),
    );
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
}

class _ConfigurableTelemetrySink
    implements TelemetrySink, TelemetryCollectionConfigurable {
  final collectionSettings = <_CollectionSettings>[];

  @override
  void setCollectionEnabled({
    required bool analyticsEnabled,
    required bool diagnosticsEnabled,
  }) {
    collectionSettings.add(
      _CollectionSettings(
        analyticsEnabled: analyticsEnabled,
        diagnosticsEnabled: diagnosticsEnabled,
      ),
    );
  }

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {}

  @override
  void trackScreenView(
    String screenName, {
    String? screenClass,
    Map<String, Object?> properties = const {},
  }) {}

  @override
  void addBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {}

  @override
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  }) {}

  @override
  Future<void> flush() async {}
}

class _CollectionSettings {
  const _CollectionSettings({
    required this.analyticsEnabled,
    required this.diagnosticsEnabled,
  });

  final bool analyticsEnabled;
  final bool diagnosticsEnabled;

  @override
  bool operator ==(Object other) {
    return other is _CollectionSettings &&
        other.analyticsEnabled == analyticsEnabled &&
        other.diagnosticsEnabled == diagnosticsEnabled;
  }

  @override
  int get hashCode => Object.hash(analyticsEnabled, diagnosticsEnabled);

  @override
  String toString() {
    return 'CollectionSettings('
        'analyticsEnabled: $analyticsEnabled, '
        'diagnosticsEnabled: $diagnosticsEnabled)';
  }
}

class _RecordedEvent {
  const _RecordedEvent(this.name, this.properties);

  final String name;
  final Map<String, Object?> properties;
}

class _RecordedScreenView {
  const _RecordedScreenView({
    required this.screenName,
    required this.screenClass,
    required this.properties,
  });

  final String screenName;
  final String? screenClass;
  final Map<String, Object?> properties;

  @override
  bool operator ==(Object other) {
    return other is _RecordedScreenView &&
        other.screenName == screenName &&
        other.screenClass == screenClass &&
        _mapEquals(other.properties, properties);
  }

  @override
  int get hashCode => Object.hash(screenName, screenClass, properties);

  @override
  String toString() {
    return 'ScreenView('
        'screenName: $screenName, '
        'screenClass: $screenClass, '
        'properties: $properties)';
  }
}

class _RecordedError {
  const _RecordedError(this.error, this.stackTrace, this.properties);

  final Object error;
  final StackTrace? stackTrace;
  final Map<String, Object?> properties;
}

bool _mapEquals(Map<String, Object?> left, Map<String, Object?> right) {
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
