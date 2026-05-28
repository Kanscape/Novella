enum AnnouncementSource { app, server }

enum AnnouncementCompletionActionType { dismiss, openAbout }

class AnnouncementCompletionAction {
  const AnnouncementCompletionAction(this.type);

  const AnnouncementCompletionAction.dismiss()
    : type = AnnouncementCompletionActionType.dismiss;

  const AnnouncementCompletionAction.openAbout()
    : type = AnnouncementCompletionActionType.openAbout;

  factory AnnouncementCompletionAction.fromJson(dynamic json) {
    if (json is! Map) {
      return const AnnouncementCompletionAction.dismiss();
    }

    switch (_toString(json['type'])) {
      case 'openAbout':
        return const AnnouncementCompletionAction.openAbout();
      default:
        return const AnnouncementCompletionAction.dismiss();
    }
  }

  final AnnouncementCompletionActionType type;
}

class AppAnnouncementManifest {
  const AppAnnouncementManifest({
    required this.version,
    required this.announcements,
  });

  factory AppAnnouncementManifest.fromJson(Map<String, dynamic> json) {
    final rows = json['announcements'];
    final announcements =
        rows is List
            ? rows
                .whereType<Map>()
                .map(AppAnnouncement.tryParse)
                .whereType<AppAnnouncement>()
                .toList(growable: false)
            : const <AppAnnouncement>[];

    return AppAnnouncementManifest(
      version: _toInt(json['version'], fallback: 1),
      announcements: announcements,
    );
  }

  final int version;
  final List<AppAnnouncement> announcements;
}

class AppAnnouncement {
  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.publishedAt,
    required this.summary,
    required this.path,
    required this.required,
    required this.requiredReadSeconds,
    required this.completionAction,
  });

  static AppAnnouncement? tryParse(Map<dynamic, dynamic> json) {
    final id = _toString(json['id']).trim();
    final title = _toString(json['title']).trim();
    final path = _toString(json['path']).trim();
    final publishedAt = DateTime.tryParse(_toString(json['publishedAt']));

    if (id.isEmpty || title.isEmpty || path.isEmpty || publishedAt == null) {
      return null;
    }

    final seconds = _toInt(json['requiredReadSeconds'], fallback: 8);

    return AppAnnouncement(
      id: id,
      title: title,
      publishedAt: publishedAt,
      summary: _toString(json['summary']).trim(),
      path: path,
      required: _toBool(json['required']),
      requiredReadSeconds: seconds > 0 ? seconds : 8,
      completionAction: AnnouncementCompletionAction.fromJson(
        json['completionAction'],
      ),
    );
  }

  final String id;
  final String title;
  final DateTime publishedAt;
  final String summary;
  final String path;
  final bool required;
  final int requiredReadSeconds;
  final AnnouncementCompletionAction completionAction;

  String get readKey => 'app:$id';
}

class ServerAnnouncement {
  const ServerAnnouncement({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.contentHtml,
  });

  factory ServerAnnouncement.fromJson(Map<dynamic, dynamic> json) {
    return ServerAnnouncement(
      id: _toInt(json['Id']),
      title: _toString(json['Title']).trim(),
      createdAt:
          DateTime.tryParse(_toString(json['CreatedAt'])) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      contentHtml: _toString(json['Content']),
    );
  }

  final int id;
  final String title;
  final DateTime createdAt;
  final String contentHtml;

  String get readKey => 'server:$id';
}

class ServerAnnouncementPage {
  const ServerAnnouncementPage({
    required this.page,
    required this.totalPages,
    required this.announcements,
  });

  factory ServerAnnouncementPage.fromJson(Map<dynamic, dynamic> json) {
    final rows = json['Data'];
    return ServerAnnouncementPage(
      page: _toInt(json['Page'], fallback: 1),
      totalPages: _toInt(json['TotalPages'], fallback: 1),
      announcements:
          rows is List
              ? rows
                  .whereType<Map>()
                  .map(ServerAnnouncement.fromJson)
                  .toList(growable: false)
              : const <ServerAnnouncement>[],
    );
  }

  final int page;
  final int totalPages;
  final List<ServerAnnouncement> announcements;
}

class AnnouncementListItem {
  const AnnouncementListItem._({
    required this.source,
    required this.id,
    required this.serverId,
    required this.title,
    required this.publishedAt,
    required this.summary,
    required this.readKey,
    required this.required,
    required this.requiredReadSeconds,
    required this.completionAction,
    required this.isRead,
    required this.appAnnouncement,
    required this.serverAnnouncement,
  });

  factory AnnouncementListItem.app(
    AppAnnouncement announcement, {
    required bool isRead,
  }) {
    return AnnouncementListItem._(
      source: AnnouncementSource.app,
      id: announcement.id,
      serverId: null,
      title: announcement.title,
      publishedAt: announcement.publishedAt,
      summary: announcement.summary,
      readKey: announcement.readKey,
      required: announcement.required,
      requiredReadSeconds: announcement.requiredReadSeconds,
      completionAction: announcement.completionAction,
      isRead: isRead,
      appAnnouncement: announcement,
      serverAnnouncement: null,
    );
  }

  factory AnnouncementListItem.server(
    ServerAnnouncement announcement, {
    required String summary,
    required bool isRead,
  }) {
    return AnnouncementListItem._(
      source: AnnouncementSource.server,
      id: announcement.id.toString(),
      serverId: announcement.id,
      title: announcement.title,
      publishedAt: announcement.createdAt,
      summary: summary,
      readKey: announcement.readKey,
      required: false,
      requiredReadSeconds: 0,
      completionAction: const AnnouncementCompletionAction.dismiss(),
      isRead: isRead,
      appAnnouncement: null,
      serverAnnouncement: announcement,
    );
  }

  AnnouncementListItem copyWith({bool? isRead}) {
    return AnnouncementListItem._(
      source: source,
      id: id,
      serverId: serverId,
      title: title,
      publishedAt: publishedAt,
      summary: summary,
      readKey: readKey,
      required: required,
      requiredReadSeconds: requiredReadSeconds,
      completionAction: completionAction,
      isRead: isRead ?? this.isRead,
      appAnnouncement: appAnnouncement,
      serverAnnouncement: serverAnnouncement,
    );
  }

  final AnnouncementSource source;
  final String id;
  final int? serverId;
  final String title;
  final DateTime publishedAt;
  final String summary;
  final String readKey;
  final bool required;
  final int requiredReadSeconds;
  final AnnouncementCompletionAction completionAction;
  final bool isRead;
  final AppAnnouncement? appAnnouncement;
  final ServerAnnouncement? serverAnnouncement;
}

int _toInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

String _toString(dynamic value, {String fallback = ''}) {
  final result = value?.toString();
  if (result == null || result == 'null') {
    return fallback;
  }
  return result;
}
