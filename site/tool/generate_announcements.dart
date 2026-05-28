import 'dart:convert';
import 'dart:io';

const _defaultAnnouncementsDir = 'web/assets/announcements';
const _defaultIndexPath = 'web/assets/announcements/index.json';

Future<void> main() async {
  final announcementsDir = Directory(
    Platform.environment['ANNOUNCEMENTS_DIR'] ?? _defaultAnnouncementsDir,
  );
  final indexFile = File(
    Platform.environment['ANNOUNCEMENTS_INDEX_PATH'] ?? _defaultIndexPath,
  );

  if (!await announcementsDir.exists()) {
    await announcementsDir.create(recursive: true);
  }

  final markdownFiles =
      announcementsDir
          .listSync(recursive: false)
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final announcements = <Map<String, dynamic>>[];
  for (final file in markdownFiles) {
    announcements.add(await _buildAnnouncement(file));
  }

  announcements.sort(
    (a, b) =>
        (b['publishedAt'] as String).compareTo(a['publishedAt'] as String),
  );

  await indexFile.parent.create(recursive: true);
  final indexJson = const JsonEncoder.withIndent(
    '  ',
  ).convert({'version': 1, 'announcements': announcements});
  await indexFile.writeAsString('$indexJson\n');

  stdout.writeln(
    'Generated ${announcements.length} announcement(s) -> ${indexFile.path}',
  );
}

Future<Map<String, dynamic>> _buildAnnouncement(File file) async {
  final source = await file.readAsString();
  final parsed = _parseFrontMatter(source);
  final metadata = parsed.metadata;
  final body = parsed.body;
  final id = _stringValue(metadata, 'id') ?? _basenameWithoutExtension(file);
  final title = _stringValue(metadata, 'title') ?? _extractTitle(body);
  final publishedAt = _resolvePublishedAt(
    _stringValue(metadata, 'publishedAt'),
    file.path,
  );

  if (title == null || title.trim().isEmpty) {
    throw FormatException(
      'Announcement ${file.path} must define title or start with a Markdown heading.',
    );
  }
  if (publishedAt == null) {
    throw FormatException(
      'Announcement ${file.path} must define publishedAt or include YYYY-MM-DD in its filename.',
    );
  }

  final required = _boolValue(metadata, 'required') ?? false;
  final requiredReadSeconds = _positiveIntValue(
    metadata,
    'requiredReadSeconds',
  );
  final completionAction = _stringValue(metadata, 'completionAction');

  final result = <String, dynamic>{
    'id': id,
    'title': title.trim(),
    'publishedAt': publishedAt,
    'summary': _stringValue(metadata, 'summary') ?? _extractSummary(body),
    'path': _assetPath(file),
    'required': required,
  };

  if (requiredReadSeconds != null) {
    result['requiredReadSeconds'] = requiredReadSeconds;
  }
  if (completionAction != null && completionAction.isNotEmpty) {
    result['completionAction'] = {'type': completionAction};
  }

  return result;
}

({Map<String, String> metadata, String body}) _parseFrontMatter(String source) {
  final normalized = source.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    return (metadata: const <String, String>{}, body: normalized);
  }

  final metadataLines = <String>[];
  var closingIndex = -1;
  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      closingIndex = i;
      break;
    }
    metadataLines.add(lines[i]);
  }

  if (closingIndex == -1) {
    throw const FormatException('Front matter is missing a closing --- line.');
  }

  final metadata = <String, String>{};
  for (final line in metadataLines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final separator = trimmed.indexOf(':');
    if (separator <= 0) {
      throw FormatException('Invalid front matter line: $line');
    }
    final key = trimmed.substring(0, separator).trim();
    final value = trimmed.substring(separator + 1).trim();
    metadata[key] = _unquote(value);
  }

  return (metadata: metadata, body: lines.skip(closingIndex + 1).join('\n'));
}

String? _stringValue(Map<String, String> metadata, String key) {
  final value = metadata[key]?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

bool? _boolValue(Map<String, String> metadata, String key) {
  final value = _stringValue(metadata, key)?.toLowerCase();
  if (value == null) {
    return null;
  }
  if (value == 'true' || value == '1') {
    return true;
  }
  if (value == 'false' || value == '0') {
    return false;
  }
  throw FormatException('$key must be true or false.');
}

int? _positiveIntValue(Map<String, String> metadata, String key) {
  final value = _stringValue(metadata, key);
  if (value == null) {
    return null;
  }
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('$key must be a positive integer.');
  }
  return parsed;
}

String? _resolvePublishedAt(String? raw, String path) {
  if (raw != null) {
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) {
      return '${raw}T00:00:00.000Z';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed.toUtc().toIso8601String();
    }
    throw FormatException('publishedAt is not a valid ISO 8601 value: $raw');
  }

  final match = RegExp(r'(20\d{2}-\d{2}-\d{2})').firstMatch(path);
  if (match == null) {
    return null;
  }
  return '${match.group(1)}T00:00:00.000Z';
}

String? _extractTitle(String body) {
  for (final line in body.split('\n')) {
    final match = RegExp(r'^\s*#\s+(.+)$').firstMatch(line);
    if (match != null) {
      return match.group(1)?.trim();
    }
  }
  return null;
}

String _extractSummary(String body) {
  for (final line in body.split('\n')) {
    if (RegExp(r'^\s{0,3}#{1,6}\s+').hasMatch(line)) {
      continue;
    }
    final cleaned = _stripMarkdown(line);
    if (cleaned.isNotEmpty) {
      return cleaned.length > 80 ? '${cleaned.substring(0, 80)}...' : cleaned;
    }
  }
  return '';
}

String _stripMarkdown(String line) {
  return line
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+'), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+'), '')
      .replaceAll(RegExp(r'[`*_~]'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (match) {
        return match.group(1) ?? '';
      })
      .trim();
}

String _assetPath(File file) {
  final normalized = file.path.replaceAll('\\', '/');
  if (normalized.startsWith('web/')) {
    return normalized.substring('web/'.length);
  }
  final webIndex = normalized.indexOf('/web/');
  if (webIndex >= 0) {
    return normalized.substring(webIndex + '/web/'.length);
  }
  return normalized;
}

String _basenameWithoutExtension(File file) {
  final normalized = file.path.replaceAll('\\', '/');
  final fileName = normalized.substring(normalized.lastIndexOf('/') + 1);
  final dotIndex = fileName.lastIndexOf('.');
  return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
}

String _unquote(String value) {
  if (value.length < 2) {
    return value;
  }
  final first = value[0];
  final last = value[value.length - 1];
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1);
  }
  return value;
}
