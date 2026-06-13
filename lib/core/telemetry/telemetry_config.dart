import 'package:flutter/foundation.dart';
import 'package:novella/core/config/app_build_info.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rena_rtk/rena_rtk.dart';

class TelemetryConfig {
  const TelemetryConfig({
    required this.endpoint,
    required this.publicWriteKey,
    required this.environment,
    required this.appVersion,
    required this.buildNumber,
    required this.debug,
  });

  static const _endpointValue = String.fromEnvironment('RENA_ENDPOINT');
  static const _publicWriteKeyValue = String.fromEnvironment(
    'RENA_PUBLIC_WRITE_KEY',
  );
  static const _environmentValue = String.fromEnvironment('RENA_ENVIRONMENT');
  static const _debugValue = bool.fromEnvironment(
    'RENA_TELEMETRY_DEBUG',
    defaultValue: kDebugMode,
  );

  final Uri? endpoint;
  final String? publicWriteKey;
  final String environment;
  final String appVersion;
  final String? buildNumber;
  final bool debug;

  bool get isConfigured =>
      endpoint != null && (publicWriteKey?.isNotEmpty ?? false);

  static TelemetryConfig fromEnvironment({required PackageInfo packageInfo}) {
    final endpointText = _endpointValue.trim();
    final environmentText = _environmentValue.trim();
    return TelemetryConfig(
      endpoint: _parseEndpoint(endpointText),
      publicWriteKey:
          _publicWriteKeyValue.trim().isEmpty
              ? null
              : _publicWriteKeyValue.trim(),
      environment:
          environmentText.isEmpty
              ? (kReleaseMode ? 'production' : 'development')
              : environmentText,
      appVersion: packageInfo.version,
      buildNumber: AppBuildInfo.getTelemetryBuildNumber(
        packageInfo.buildNumber,
      ),
      debug: _debugValue,
    );
  }

  static Uri? _parseEndpoint(String value) {
    if (value.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute) {
      return null;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return null;
    }
    return uri;
  }

  RTKConfig toRTKConfig() {
    if (!isConfigured) {
      throw StateError('Rena telemetry is not configured.');
    }
    return RTKConfig(
      endpoint: endpoint!,
      publicWriteKey: publicWriteKey!,
      environment: environment,
      appVersion: appVersion,
      buildNumber: buildNumber,
      debug: debug,
    );
  }
}
