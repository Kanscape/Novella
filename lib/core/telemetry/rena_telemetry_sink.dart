import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';
import 'package:rena_rtk/rena_rtk.dart';

abstract interface class RenaTelemetryClient {
  void track(String name, {Map<String, Object?> properties = const {}});

  void addBreadcrumb(String name, {Map<String, Object?> properties = const {}});

  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  });

  Future<void> flush();

  void setSuperProperties(Map<String, Object?> properties);
}

class RenaRtkTelemetryAdapter implements RenaTelemetryClient {
  const RenaRtkTelemetryAdapter();

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {
    RTK.track(name, properties: properties);
  }

  @override
  void addBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {
    RTK.addBreadcrumb(name, properties: properties);
  }

  @override
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  }) {
    RTK.captureError(error, stackTrace: stackTrace, properties: properties);
  }

  @override
  Future<void> flush() => RTK.flush();

  @override
  void setSuperProperties(Map<String, Object?> properties) {
    RTK.setSuperProperties(properties);
  }
}

class RenaTelemetrySink
    implements TelemetrySink, TelemetryCollectionConfigurable {
  const RenaTelemetrySink({this.client = const RenaRtkTelemetryAdapter()});

  static const _screenViewEventName = 'screen_view';
  static const _screenClassProperty = 'screen_class';

  final RenaTelemetryClient client;

  @override
  void track(String name, {Map<String, Object?> properties = const {}}) {
    client.track(name, properties: properties);
  }

  @override
  void trackScreenView(
    String screenName, {
    String? screenClass,
    Map<String, Object?> properties = const {},
  }) {
    client.track(
      _screenViewEventName,
      properties: {
        ...properties,
        TelemetryProperties.screenName: screenName,
        if (screenClass != null) _screenClassProperty: screenClass,
      },
    );
  }

  @override
  void addBreadcrumb(
    String name, {
    Map<String, Object?> properties = const {},
  }) {
    client.addBreadcrumb(name, properties: properties);
  }

  @override
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  }) {
    client.captureError(error, stackTrace: stackTrace, properties: properties);
  }

  @override
  Future<void> flush() => client.flush();

  void setBuildMetadata({
    required String buildChannel,
    required String buildLabel,
  }) {
    client.setSuperProperties({
      TelemetryProperties.buildChannel: buildChannel,
      TelemetryProperties.buildLabel: buildLabel,
    });
  }

  @override
  void setCollectionEnabled({
    required bool analyticsEnabled,
    required bool diagnosticsEnabled,
  }) {}
}
