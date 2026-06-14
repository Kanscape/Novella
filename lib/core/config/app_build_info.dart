class AppBuildInfo {
  const AppBuildInfo._();

  static const String buildChannel = String.fromEnvironment(
    'BUILD_CHANNEL',
    defaultValue: 'local',
  );
  static const String buildLabel = String.fromEnvironment(
    'BUILD_LABEL',
    defaultValue: 'Local Build',
  );

  static bool get isLocalBuild => buildChannel == 'local';

  static bool get isOfficialBuild => buildChannel == 'main';

  static String getDisplayVersion(String baseVersion) {
    return getDisplayVersionFor(
      baseVersion: baseVersion,
      buildLabel: buildLabel,
    );
  }

  static String getDisplayVersionFor({
    required String baseVersion,
    required String buildLabel,
  }) {
    final normalizedVersion = baseVersion.trim();
    if (normalizedVersion.isEmpty) {
      return '';
    }

    final normalizedLabel = buildLabel.trim();
    if (normalizedLabel.isEmpty) {
      return normalizedVersion;
    }
    return '$normalizedVersion ($normalizedLabel)';
  }

  static String? getTelemetryBuildNumber(String? buildNumber) {
    return telemetryBuildNumberFor(
      buildChannel: buildChannel,
      buildNumber: buildNumber,
    );
  }

  static String? telemetryBuildNumberFor({
    required String buildChannel,
    required String? buildNumber,
  }) {
    if (buildChannel != 'main') {
      return null;
    }
    final normalizedBuildNumber = buildNumber?.trim() ?? '';
    if (normalizedBuildNumber.isEmpty) {
      return null;
    }
    return normalizedBuildNumber;
  }
}
