import 'package:novella/core/telemetry/telemetry_events.dart';

class TelemetrySanitizer {
  const TelemetrySanitizer._();

  static const Set<String> _allowedUsageProperties = {
    TelemetryProperties.action,
    TelemetryProperties.appVersion,
    TelemetryProperties.buildNumber,
    TelemetryProperties.dayType,
    TelemetryProperties.enabledHomeModules,
    TelemetryProperties.homeModuleOrder,
    TelemetryProperties.homeRankType,
    TelemetryProperties.ignoreAI,
    TelemetryProperties.ignoreJapanese,
    TelemetryProperties.ignoreLevel6,
    TelemetryProperties.item,
    TelemetryProperties.module,
    TelemetryProperties.platform,
    TelemetryProperties.readerViewMode,
    TelemetryProperties.seriesSearchMode,
    TelemetryProperties.source,
    TelemetryProperties.startupTab,
    TelemetryProperties.tab,
    TelemetryProperties.target,
  };

  static const Set<String> _allowedDiagnosticProperties = {
    TelemetryProperties.dayType,
    TelemetryProperties.module,
    TelemetryProperties.readerViewMode,
    TelemetryProperties.screenName,
    TelemetryProperties.source,
    TelemetryProperties.startupTab,
    TelemetryProperties.tab,
  };

  static Map<String, Object?> usageProperties(Map<String, Object?> properties) {
    return _sanitizeProperties(properties, _allowedUsageProperties);
  }

  static Map<String, Object?> diagnosticProperties(
    Map<String, Object?> properties,
  ) {
    return _sanitizeProperties(properties, _allowedDiagnosticProperties);
  }

  static String sanitizeMessage(Object error) {
    final raw = error.toString();
    final withoutAuthorizationHeaders = raw.replaceAllMapped(
      RegExp(
        r'\b(authorization|proxy-authorization)\s*[:=]\s*[^,\r\n]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}=[redacted]',
    );
    final withoutBearerTokens = withoutAuthorizationHeaders.replaceAll(
      RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
      'Bearer [redacted]',
    );
    final withoutUrls = withoutBearerTokens.replaceAll(
      RegExp(r'https?://\S+'),
      '[url]',
    );
    final withoutUnixPaths = withoutUrls.replaceAll(
      RegExp(
        r'(/Users|/home|/root|/private|/var|/tmp|/data/(?:user/\d+|data)|/storage/emulated/\d+)/\S+',
      ),
      '[path]',
    );
    final withoutPaths = withoutUnixPaths.replaceAll(
      RegExp(r'[A-Za-z]:\\[^\s]+'),
      '[path]',
    );
    final withoutSecrets = withoutPaths.replaceAllMapped(
      RegExp(
        r'''(["']?)\b([A-Za-z][A-Za-z0-9_-]*)\b\1\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^,\s}\]]+)''',
        caseSensitive: false,
      ),
      (match) {
        final key = match.group(2)!;
        if (!_isSensitiveKey(key)) {
          return match.group(0)!;
        }
        return '${match.group(1)}$key${match.group(1)}=[redacted]';
      },
    );
    return withoutSecrets.length <= 300
        ? withoutSecrets
        : withoutSecrets.substring(0, 300);
  }

  static StackTrace? sanitizeStackTrace(StackTrace? stackTrace) {
    if (stackTrace == null) {
      return null;
    }
    final lines =
        stackTrace
            .toString()
            .split('\n')
            .where(
              (line) => line.contains('package:') || line.contains('dart:'),
            )
            .take(40)
            .toList();
    if (lines.isEmpty) {
      return null;
    }
    return StackTrace.fromString(lines.join('\n'));
  }

  static Map<String, Object?> _sanitizeProperties(
    Map<String, Object?> properties,
    Set<String> allowedKeys,
  ) {
    final sanitized = <String, Object?>{};
    for (final entry in properties.entries) {
      if (!allowedKeys.contains(entry.key)) {
        continue;
      }
      final value = _sanitizeValue(entry.value);
      if (value != null || entry.value == null) {
        sanitized[entry.key] = value;
      }
    }
    return sanitized;
  }

  static Object? _sanitizeValue(Object? value) {
    return switch (value) {
      null => null,
      bool() => value,
      num() => value,
      String() => sanitizeMessage(value),
      Iterable<Object?>() =>
        value
            .map(_sanitizeValue)
            .where((item) => item != null)
            .cast<Object?>()
            .toList(),
      _ => null,
    };
  }

  static bool _isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    if (lower == 'key' || lower.endsWith('_key') || lower.endsWith('-key')) {
      return true;
    }
    if (RegExp(r'[A-Za-z0-9](?:Key|KEY)$').hasMatch(key)) {
      return true;
    }
    return lower.contains('authorization') ||
        lower.contains('cookie') ||
        lower.contains('token') ||
        lower.contains('password') ||
        lower.contains('secret');
  }
}
