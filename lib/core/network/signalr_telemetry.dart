import 'package:dio/dio.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';

class SignalRHubTelemetrySources {
  const SignalRHubTelemetrySources._();

  static const closed = 'closed';
  static const connect = 'connect';
  static const eventHandler = 'event_handler';
  static const invoke = 'invoke';
  static const reconnecting = 'reconnecting';
  static const restart = 'restart';
  static const stop = 'stop';

  static const _known = <String>{
    closed,
    connect,
    eventHandler,
    invoke,
    reconnecting,
    restart,
    stop,
  };

  static String safe(String source) {
    return _known.contains(source) ? source : 'unknown';
  }
}

class SignalRHubTelemetry {
  const SignalRHubTelemetry._();

  static const module = 'signalr_hub';

  static void capture(
    Object error, {
    StackTrace? stackTrace,
    required String source,
  }) {
    final safeSource = SignalRHubTelemetrySources.safe(source);
    final telemetryError = SignalRHubTelemetryError.from(
      error,
      source: safeSource,
    );
    TelemetryService.instance.captureError(
      telemetryError,
      stackTrace: stackTrace,
      module: module,
      reportable: telemetryError.isReportable,
      properties: {TelemetryProperties.source: safeSource},
    );
  }
}

class SignalRHubTelemetryError {
  const SignalRHubTelemetryError({
    required this.source,
    required this.originalType,
    required this.category,
    this.statusCode,
  });

  factory SignalRHubTelemetryError.from(
    Object error, {
    required String source,
  }) {
    return SignalRHubTelemetryError(
      source: source,
      originalType: error.runtimeType.toString(),
      category: _categoryFor(error),
      statusCode: _statusCodeFor(error),
    );
  }

  final String source;
  final String originalType;
  final String category;
  final int? statusCode;

  bool get isReportable {
    return switch (category) {
      'network' || 'timeout' || 'cancelled' => false,
      _ => true,
    };
  }

  @override
  String toString() {
    final status = statusCode == null ? '' : ' status=$statusCode';
    return 'signalr_hub source=$source type=$originalType '
        'category=$category$status';
  }

  static int? _statusCodeFor(Object error) {
    if (error is DioException) {
      return error.response?.statusCode;
    }
    return null;
  }

  static String _categoryFor(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return 'auth';
      }
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => 'timeout',
        DioExceptionType.connectionError => 'network',
        DioExceptionType.cancel => 'cancelled',
        DioExceptionType.badResponse => 'server_error',
        _ => _categoryForText(error.toString()),
      };
    }
    return _categoryForText(error.toString());
  }

  static String _categoryForText(String raw) {
    final text = raw.toLowerCase();
    if (text.contains('unauthorized') ||
        text.contains('authorization') ||
        text.contains('bearer') ||
        text.contains('no token') ||
        text.contains('notoken') ||
        text.contains('401') ||
        text.contains('403') ||
        text.contains('token') ||
        text.contains('权限') ||
        text.contains('凭据')) {
      return 'auth';
    }
    if (text.contains('timeout') || text.contains('timed out')) {
      return 'timeout';
    }
    if (text.contains('cancel') || text.contains('cancelled')) {
      return 'cancelled';
    }
    if (text.contains('socket') ||
        text.contains('connection') ||
        text.contains('transport') ||
        text.contains('websocket') ||
        text.contains('handshake')) {
      return 'network';
    }
    if (text.contains('server error') ||
        text.contains('status') ||
        text.contains('bad response')) {
      return 'server_error';
    }
    if (text.contains('json') ||
        text.contains('gzip') ||
        text.contains('format') ||
        text.contains('protocol') ||
        text.contains('type')) {
      return 'protocol';
    }
    return 'unknown';
  }
}
