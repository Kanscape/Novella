import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/config/app_build_info.dart';
import 'package:novella/core/telemetry/firebase_telemetry_clients.dart';
import 'package:novella/core/telemetry/firebase_telemetry_sink.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/firebase_options.dart';

class FirebaseTelemetryBootstrap {
  const FirebaseTelemetryBootstrap._();

  static final Logger _logger = Logger('FirebaseTelemetry');

  static const analyticsEnabledKey = 'telemetry_analytics_enabled';
  static const diagnosticsEnabledKey = 'telemetry_diagnostics_enabled';
  static const nonFatalErrorSampleRateKey =
      'telemetry_non_fatal_error_sample_rate';

  @visibleForTesting
  static const startupRemotePolicy = TelemetryRemotePolicy(
    analyticsEnabled: false,
    diagnosticsEnabled: false,
    usageCollectionPending: true,
  );

  static Future<void> configureFromEnvironment({
    required bool diagnosticsEnabled,
  }) async {
    TelemetryService.instance.configure(
      diagnosticsEnabled: diagnosticsEnabled,
      remotePolicy: startupRemotePolicy,
    );

    if (!_isRuntimeSupported) {
      return;
    }

    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final sink = FirebaseTelemetrySink(
      analytics: FirebaseAnalyticsTelemetryAdapter(
        FirebaseAnalytics.instanceFor(app: app),
      ),
      crashlytics: FirebaseCrashlyticsTelemetryAdapter(
        FirebaseCrashlytics.instance,
      ),
    );
    sink.setBuildMetadata(
      buildChannel: AppBuildInfo.buildChannel,
      buildLabel: AppBuildInfo.buildLabel,
    );

    TelemetryService.instance.configure(
      sink: sink,
      diagnosticsEnabled: diagnosticsEnabled,
      remotePolicy: startupRemotePolicy,
    );

    final remoteConfig = FirebaseRemoteConfig.instance;
    await _configureRemoteConfig(remoteConfig);
    TelemetryService.instance.setRemotePolicy(
      _remotePolicyFrom(
        remoteConfig,
        usageCollectionPending: !_hasRemoteAnalyticsPolicy(remoteConfig),
      ),
    );
    unawaited(_refreshRemotePolicy(remoteConfig));
  }

  static bool get _isRuntimeSupported {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  static Future<void> _configureRemoteConfig(
    FirebaseRemoteConfig remoteConfig,
  ) async {
    await remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 3),
        minimumFetchInterval:
            kReleaseMode
                ? const Duration(hours: 12)
                : const Duration(minutes: 5),
      ),
    );
    await remoteConfig.setDefaults(const {
      analyticsEnabledKey: false,
      diagnosticsEnabledKey: false,
      nonFatalErrorSampleRateKey: 1.0,
    });
  }

  static Future<void> _refreshRemotePolicy(
    FirebaseRemoteConfig remoteConfig,
  ) async {
    try {
      await remoteConfig.fetchAndActivate();
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to fetch Firebase Remote Config',
        error,
        stackTrace,
      );
    }

    TelemetryService.instance.setRemotePolicy(_remotePolicyFrom(remoteConfig));
  }

  static TelemetryRemotePolicy _remotePolicyFrom(
    FirebaseRemoteConfig remoteConfig, {
    bool usageCollectionPending = false,
  }) {
    return TelemetryRemotePolicy(
      analyticsEnabled: remoteConfig.getBool(analyticsEnabledKey),
      diagnosticsEnabled: remoteConfig.getBool(diagnosticsEnabledKey),
      nonFatalErrorSampleRate: remoteConfig.getDouble(
        nonFatalErrorSampleRateKey,
      ),
      usageCollectionPending: usageCollectionPending,
    );
  }

  static bool _hasRemoteAnalyticsPolicy(FirebaseRemoteConfig remoteConfig) {
    return remoteConfig.getValue(analyticsEnabledKey).source ==
        ValueSource.valueRemote;
  }
}
