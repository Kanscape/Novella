import 'package:novella/core/telemetry/telemetry_config.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rena_rtk/rena_rtk.dart';

class RenaTelemetrySink implements TelemetrySink {
  const RenaTelemetrySink();

  static Future<void> configureFromEnvironment({
    required bool diagnosticsEnabled,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final config = TelemetryConfig.fromEnvironment(packageInfo: packageInfo);

    TelemetryService.instance.configure(diagnosticsEnabled: diagnosticsEnabled);

    if (!config.isConfigured) {
      return;
    }

    await RTK.init(config.toRTKConfig());
    TelemetryService.instance.configure(sink: const RenaTelemetrySink());
  }

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
}
