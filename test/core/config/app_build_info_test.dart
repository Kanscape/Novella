import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/config/app_build_info.dart';

void main() {
  test('formats build labels without exposing platform build numbers', () {
    expect(
      AppBuildInfo.getDisplayVersionFor(
        baseVersion: '1.9.0',
        buildLabel: 'Build 279',
      ),
      '1.9.0 (Build 279)',
    );
    expect(
      AppBuildInfo.getDisplayVersionFor(
        baseVersion: '1.9.0',
        buildLabel: 'PR #123',
      ),
      '1.9.0 (PR #123)',
    );
    expect(
      AppBuildInfo.getDisplayVersionFor(
        baseVersion: '1.9.0',
        buildLabel: 'feature/foo',
      ),
      '1.9.0 (feature/foo)',
    );
    expect(
      AppBuildInfo.getDisplayVersionFor(
        baseVersion: '1.9.0',
        buildLabel: 'Local Build',
      ),
      '1.9.0 (Local Build)',
    );
  });

  test('only official main builds expose telemetry build number', () {
    expect(
      AppBuildInfo.telemetryBuildNumberFor(
        buildChannel: 'main',
        buildNumber: '279',
      ),
      '279',
    );
    expect(
      AppBuildInfo.telemetryBuildNumberFor(
        buildChannel: 'pr',
        buildNumber: '279',
      ),
      isNull,
    );
    expect(
      AppBuildInfo.telemetryBuildNumberFor(
        buildChannel: 'branch',
        buildNumber: '279',
      ),
      isNull,
    );
    expect(
      AppBuildInfo.telemetryBuildNumberFor(
        buildChannel: 'local',
        buildNumber: '1',
      ),
      isNull,
    );
  });
}
