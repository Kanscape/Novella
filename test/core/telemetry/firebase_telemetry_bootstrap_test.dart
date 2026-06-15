import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/telemetry/firebase_telemetry_bootstrap.dart';

void main() {
  test('starts Firebase collection disabled until Remote Config applies', () {
    expect(
      FirebaseTelemetryBootstrap.startupRemotePolicy.analyticsEnabled,
      false,
    );
    expect(
      FirebaseTelemetryBootstrap.startupRemotePolicy.diagnosticsEnabled,
      false,
    );
    expect(
      FirebaseTelemetryBootstrap.startupRemotePolicy.usageCollectionPending,
      true,
    );
  });
}
