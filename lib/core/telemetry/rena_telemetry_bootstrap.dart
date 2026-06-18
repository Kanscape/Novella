import 'package:novella/core/config/app_build_info.dart';
import 'package:novella/core/telemetry/rena_telemetry_sink.dart';
import 'package:novella/core/telemetry/telemetry_config.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rena_rtk/rena_rtk.dart';

class RenaTelemetryBootstrap {
  const RenaTelemetryBootstrap._();

  static Future<void> configureFromEnvironment({
    required bool diagnosticsEnabled,
  }) async {
    TelemetryService.instance.configure(diagnosticsEnabled: diagnosticsEnabled);

    final packageInfo = await PackageInfo.fromPlatform();
    final config = TelemetryConfig.fromEnvironment(packageInfo: packageInfo);
    if (!config.isConfigured) {
      return;
    }

    await RTK.init(config.toRTKConfig());
    final sink = RenaTelemetrySink();
    sink.setBuildMetadata(
      buildChannel: AppBuildInfo.buildChannel,
      buildLabel: AppBuildInfo.buildLabel,
    );
    TelemetryService.instance.configure(
      sink: sink,
      diagnosticsEnabled: diagnosticsEnabled,
    );
  }
}
