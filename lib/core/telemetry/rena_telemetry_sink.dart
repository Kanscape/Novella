import 'dart:convert';

import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/core/telemetry/telemetry_sink.dart';
import 'package:rena_rtk/rena_rtk.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> clearQueuedTelemetry();
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

  @override
  Future<void> clearQueuedTelemetry() async {
    // RTK v0.3.0 exposes queue clearing only through opt-out.
    await RTK.setOptOut(true);
    await RTK.setOptOut(false);
  }
}

class RenaTelemetrySink
    implements TelemetrySink, TelemetryCollectionConfigurable {
  RenaTelemetrySink({
    this.client = const RenaRtkTelemetryAdapter(),
    RenaRtkDiagnosticsQueue? diagnosticsQueue,
  }) : _diagnosticsQueue = diagnosticsQueue ?? RenaRtkDiagnosticsQueue();

  static const _screenViewEventName = 'screen_view';
  static const _screenClassProperty = 'screen_class';

  final RenaTelemetryClient client;
  final RenaRtkDiagnosticsQueue _diagnosticsQueue;
  bool _diagnosticsEnabled = true;
  bool _queuedDiagnosticErrorInMemory = false;

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
    if (!_diagnosticsEnabled) {
      return;
    }
    client.addBreadcrumb(name, properties: properties);
  }

  @override
  void captureError(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> properties = const {},
  }) {
    if (!_diagnosticsEnabled) {
      return;
    }
    _queuedDiagnosticErrorInMemory = true;
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
  Future<void> setCollectionEnabled({
    required bool analyticsEnabled,
    required bool diagnosticsEnabled,
  }) async {
    _diagnosticsEnabled = diagnosticsEnabled;
    if (!diagnosticsEnabled) {
      await _diagnosticsQueue.removePersistedErrors();
      if (_queuedDiagnosticErrorInMemory) {
        await client.clearQueuedTelemetry();
        _queuedDiagnosticErrorInMemory = false;
      }
    }
  }
}

class RenaRtkDiagnosticsQueue {
  static const _queueKey = 'rena_rtk.queue';

  Future<void> removePersistedErrors() async {
    final preferences = await SharedPreferences.getInstance();
    final rows = preferences.getStringList(_queueKey);
    if (rows == null || rows.isEmpty) {
      return;
    }

    var changed = false;
    final keptRows = <String>[];
    for (final row in rows) {
      if (_isQueuedError(row)) {
        changed = true;
        continue;
      }
      keptRows.add(row);
    }
    if (!changed) {
      return;
    }
    if (keptRows.isEmpty) {
      await preferences.remove(_queueKey);
      return;
    }
    await preferences.setStringList(_queueKey, keptRows);
  }

  bool _isQueuedError(String row) {
    try {
      final decoded = jsonDecode(row);
      if (decoded is! Map) {
        return false;
      }
      final item = decoded['item'];
      if (item is! Map) {
        return false;
      }
      return item['type'] == 'error';
    } on FormatException {
      return false;
    }
  }
}
