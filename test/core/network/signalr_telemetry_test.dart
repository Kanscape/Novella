import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/network/signalr_telemetry.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TelemetryService.instance.configure(
      sink: const NoopTelemetrySink(),
      diagnosticsEnabled: true,
    );
  });

  test('captures SignalR hub errors without raw payload details', () {
    final sink = _FakeTelemetrySink();
    TelemetryService.instance.configure(sink: sink, diagnosticsEnabled: true);

    SignalRHubTelemetry.capture(
      StateError(
        'invoke GetBook failed Authorization: Bearer abc.def.ghi '
        'https://example.com/hub/api /Users/alice/private.log '
        '{"refresh_token":"secret","book_title":"Private Title"}',
      ),
      stackTrace: StackTrace.current,
      source: SignalRHubTelemetrySources.invoke,
    );

    expect(sink.errors, hasLength(1));
    expect(sink.errors.single.properties, {
      TelemetryProperties.module: SignalRHubTelemetry.module,
      TelemetryProperties.source: SignalRHubTelemetrySources.invoke,
    });

    final message = sink.errors.single.error.toString();
    expect(message, contains('signalr_hub'));
    expect(message, contains('source=invoke'));
    expect(message, contains('type=StateError'));
    expect(message, contains('category=auth'));
    expect(message, isNot(contains('abc.def.ghi')));
    expect(message, isNot(contains('secret')));
    expect(message, isNot(contains('Private Title')));
    expect(message, isNot(contains('https://example.com/hub/api')));
    expect(message, isNot(contains('/Users/alice/private.log')));
  });
}

class _FakeTelemetrySink implements TelemetrySink {
  final errors = <_RecordedError>[];

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {}

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
  }) {
    errors.add(_RecordedError(error, stackTrace, properties));
  }

  @override
  Future<void> flush() async {}
}

class _RecordedError {
  const _RecordedError(this.error, this.stackTrace, this.properties);

  final Object error;
  final StackTrace? stackTrace;
  final Map<String, Object?> properties;
}
