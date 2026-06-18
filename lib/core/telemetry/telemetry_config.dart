import 'package:flutter/foundation.dart';
import 'package:novella/core/config/app_build_info.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rena_rtk/rena_rtk.dart';

class TelemetryConfig {
  const TelemetryConfig({
    required this.endpoint,
    required this.publicWriteKey,
    required this.appVersion,
    required this.buildNumber,
    required this.buildChannel,
    required this.buildLabel,
    required this.debug,
  });

  static const _endpointValue = String.fromEnvironment('RENA_ENDPOINT');
  static const _publicWriteKeyValue = String.fromEnvironment(
    'RENA_PUBLIC_WRITE_KEY',
  );
  static const _debugValue = bool.fromEnvironment(
    'RENA_TELEMETRY_DEBUG',
    defaultValue: kDebugMode,
  );

  final Uri? endpoint;
  final String? publicWriteKey;
  final String appVersion;
  final String? buildNumber;
  final String buildChannel;
  final String buildLabel;
  final bool debug;

  bool get isConfigured =>
      endpoint != null && (publicWriteKey?.isNotEmpty ?? false);

  static TelemetryConfig fromEnvironment({required PackageInfo packageInfo}) {
    return fromValues(
      endpointValue: _endpointValue,
      publicWriteKeyValue: _publicWriteKeyValue,
      packageInfo: packageInfo,
      buildChannel: AppBuildInfo.buildChannel,
      buildLabel: AppBuildInfo.buildLabel,
      debug: _debugValue,
    );
  }

  static TelemetryConfig fromValues({
    required String endpointValue,
    required String publicWriteKeyValue,
    required PackageInfo packageInfo,
    required String buildChannel,
    required String buildLabel,
    required bool debug,
  }) {
    return TelemetryConfig(
      endpoint: _parseEndpoint(endpointValue.trim()),
      publicWriteKey:
          publicWriteKeyValue.trim().isEmpty
              ? null
              : publicWriteKeyValue.trim(),
      appVersion: packageInfo.version,
      buildNumber: AppBuildInfo.telemetryBuildNumberFor(
        buildChannel: buildChannel,
        buildNumber: packageInfo.buildNumber,
      ),
      buildChannel: buildChannel,
      buildLabel: buildLabel,
      debug: debug,
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
      appVersion: appVersion,
      buildNumber: buildNumber,
      debug: debug,
      beforeSend: _addBuildMetadata,
    );
  }

  RTKBatchItem _addBuildMetadata(RTKBatchItem item) {
    final metadata = {
      TelemetryProperties.buildChannel: buildChannel,
      TelemetryProperties.buildLabel: buildLabel,
    };
    return switch (item) {
      RTKEvent() => RTKEvent(
        name: item.name,
        timestamp: item.timestamp,
        properties: {...metadata, ...item.properties},
      ),
      RTKError() => RTKError(
        errorType: item.errorType,
        message: item.message,
        stack: item.stack,
        timestamp: item.timestamp,
        properties: {...metadata, ...item.properties},
        breadcrumbs: item.breadcrumbs,
      ),
      _ => item,
    };
  }
}
