import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/core/network/signalr_service.dart';
import 'package:novella/features/announcements/announcement_models.dart';

typedef AnnouncementHttpGetString = Future<String> Function(Uri uri);

typedef AnnouncementSignalRInvoker =
    Future<T> Function<T>(
      String methodName, {
      List<Object>? args,
      String? requestScope,
      RequestPriority priority,
      bool bypassQueue,
    });

class AnnouncementService {
  AnnouncementService({
    AnnouncementHttpGetString? httpGetString,
    AnnouncementSignalRInvoker? signalRInvoker,
    Uri? manifestUri,
  }) : _httpGetString = httpGetString ?? _defaultHttpGetString,
       _signalRInvoker = signalRInvoker ?? SignalRService().invoke,
       manifestUri = manifestUri ?? Uri.parse(defaultManifestUrl);

  static const String defaultManifestUrl =
      'https://novella.celia.sh/assets/announcements/index.json';

  final AnnouncementHttpGetString _httpGetString;
  final AnnouncementSignalRInvoker _signalRInvoker;
  final Uri manifestUri;

  Future<AppAnnouncementManifest> fetchAppManifest() async {
    final jsonText = await _httpGetString(manifestUri);
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      return const AppAnnouncementManifest(version: 1, announcements: []);
    }
    return AppAnnouncementManifest.fromJson(decoded);
  }

  Future<String> fetchAppMarkdown(AppAnnouncement announcement) async {
    final source = await _httpGetString(resolveAppMarkdownUri(announcement));
    return _stripFrontMatter(source);
  }

  Uri resolveAppMarkdownUri(AppAnnouncement announcement) {
    final path = announcement.path.trim();
    final parsed = Uri.tryParse(path);
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }

    final root = manifestUri.replace(path: '/', query: '', fragment: '');
    final rootRelativePath = path.startsWith('/') ? path.substring(1) : path;
    return root.resolve(rootRelativePath);
  }

  Future<ServerAnnouncementPage> fetchServerAnnouncements({
    int page = 1,
    int size = 24,
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    final result = await _signalRInvoker<Map<dynamic, dynamic>>(
      'GetAnnouncementList',
      requestScope: requestScope ?? RequestScopes.home,
      priority: priority,
      args: [
        {'Page': page < 1 ? 1 : page, 'Size': size < 1 ? 1 : size},
        {'UseGzip': true},
      ],
    );
    return ServerAnnouncementPage.fromJson(result);
  }

  Future<ServerAnnouncement> fetchServerAnnouncementDetail(
    int id, {
    String? requestScope,
    RequestPriority priority = RequestPriority.high,
  }) async {
    final result = await _signalRInvoker<Map<dynamic, dynamic>>(
      'GetAnnouncementDetail',
      requestScope: requestScope ?? RequestScopes.home,
      priority: priority,
      args: [
        {'Id': id},
        {'UseGzip': true},
      ],
    );
    return ServerAnnouncement.fromJson(result);
  }

  static Future<String> _defaultHttpGetString(Uri uri) async {
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }
    return utf8.decode(response.bodyBytes);
  }
}

String _stripFrontMatter(String source) {
  final normalized = source.replaceAll('\r\n', '\n');
  final lines = normalized.split('\n');
  if (lines.isEmpty || lines.first.trim() != '---') {
    return source;
  }

  for (var i = 1; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      return lines.skip(i + 1).join('\n').trimLeft();
    }
  }

  return source;
}
