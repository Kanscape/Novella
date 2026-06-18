import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/telemetry/telemetry_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('builds RTK config from endpoint, write key, and package info', () {
    final config = TelemetryConfig.fromValues(
      endpointValue: ' https://rena.example.com/ingest/ ',
      publicWriteKeyValue: ' public-write-key ',
      packageInfo: _packageInfo(buildNumber: '128'),
      buildChannel: 'main',
      debug: false,
    );

    expect(config.isConfigured, isTrue);

    final rtkConfig = config.toRTKConfig();
    expect(rtkConfig.endpoint, Uri.parse('https://rena.example.com/ingest'));
    expect(rtkConfig.publicWriteKey, 'public-write-key');
    expect(rtkConfig.appVersion, '1.9.0');
    expect(rtkConfig.buildNumber, '128');
    expect(rtkConfig.debug, isFalse);
    expect(rtkConfig.trackForegroundDuration, isTrue);
  });

  test('ignores build number outside official main builds', () {
    final config = TelemetryConfig.fromValues(
      endpointValue: 'https://rena.example.com',
      publicWriteKeyValue: 'public-write-key',
      packageInfo: _packageInfo(buildNumber: '128'),
      buildChannel: 'pr',
      debug: true,
    );

    expect(config.toRTKConfig().buildNumber, isNull);
  });

  test('is unconfigured when endpoint or write key is missing or invalid', () {
    final missingEndpoint = TelemetryConfig.fromValues(
      endpointValue: '',
      publicWriteKeyValue: 'public-write-key',
      packageInfo: _packageInfo(),
      buildChannel: 'main',
      debug: true,
    );
    final invalidEndpoint = TelemetryConfig.fromValues(
      endpointValue: 'ftp://rena.example.com',
      publicWriteKeyValue: 'public-write-key',
      packageInfo: _packageInfo(),
      buildChannel: 'main',
      debug: true,
    );
    final missingKey = TelemetryConfig.fromValues(
      endpointValue: 'https://rena.example.com',
      publicWriteKeyValue: '   ',
      packageInfo: _packageInfo(),
      buildChannel: 'main',
      debug: true,
    );

    expect(missingEndpoint.isConfigured, isFalse);
    expect(invalidEndpoint.isConfigured, isFalse);
    expect(missingKey.isConfigured, isFalse);
  });
}

PackageInfo _packageInfo({String buildNumber = '1'}) {
  return PackageInfo(
    appName: 'Novella',
    packageName: 'sh.celia.novella',
    version: '1.9.0',
    buildNumber: buildNumber,
  );
}
