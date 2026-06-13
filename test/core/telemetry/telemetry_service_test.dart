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
  final breadcrumbs = <_RecordedEvent>[];
  final errors = <_RecordedError>[];

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
  Future<void> flush() async {}
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
