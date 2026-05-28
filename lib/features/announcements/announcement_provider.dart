import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:novella/features/announcements/announcement_models.dart';
import 'package:novella/features/announcements/announcement_read_store.dart';
import 'package:novella/features/announcements/announcement_service.dart';

final announcementServiceProvider = Provider<AnnouncementService>(
  (ref) => AnnouncementService(),
);

final announcementReadStoreProvider = Provider<AnnouncementReadStore>(
  (ref) => AnnouncementReadStore(),
);

final announcementProvider =
    AsyncNotifierProvider<AnnouncementNotifier, AnnouncementState>(
      AnnouncementNotifier.new,
    );

class AnnouncementState {
  const AnnouncementState({
    required this.items,
    this.appErrorMessage,
    this.serverErrorMessage,
  });

  const AnnouncementState.empty()
    : items = const <AnnouncementListItem>[],
      appErrorMessage = null,
      serverErrorMessage = null;

  final List<AnnouncementListItem> items;
  final String? appErrorMessage;
  final String? serverErrorMessage;

  bool get hasUnread => items.any((item) => !item.isRead);

  List<AppAnnouncement> get requiredUnreadAppAnnouncements {
    final announcements =
        items
            .where(
              (item) =>
                  item.source == AnnouncementSource.app &&
                  item.required &&
                  !item.isRead &&
                  item.appAnnouncement != null,
            )
            .map((item) => item.appAnnouncement!)
            .toList();
    announcements.sort((a, b) => a.publishedAt.compareTo(b.publishedAt));
    return announcements;
  }

  AnnouncementState copyWith({
    List<AnnouncementListItem>? items,
    String? appErrorMessage,
    String? serverErrorMessage,
  }) {
    return AnnouncementState(
      items: items ?? this.items,
      appErrorMessage: appErrorMessage ?? this.appErrorMessage,
      serverErrorMessage: serverErrorMessage ?? this.serverErrorMessage,
    );
  }
}

class AnnouncementNotifier extends AsyncNotifier<AnnouncementState> {
  @override
  Future<AnnouncementState> build() {
    return _load();
  }

  Future<void> refresh({bool silent = false}) async {
    final previous = state.asData?.value;
    if (!silent || previous == null) {
      state = const AsyncLoading<AnnouncementState>();
    }

    try {
      state = AsyncData(await _load());
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> markRead(AnnouncementListItem item) async {
    await ref.read(announcementReadStoreProvider).markRead(item.readKey);
    final current = state.asData?.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        items: current.items
            .map(
              (entry) =>
                  entry.readKey == item.readKey
                      ? entry.copyWith(isRead: true)
                      : entry,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> markAppAnnouncementRead(AppAnnouncement announcement) async {
    final item = AnnouncementListItem.app(announcement, isRead: false);
    await markRead(item);
  }

  Future<String> fetchAppMarkdown(AppAnnouncement announcement) {
    return ref.read(announcementServiceProvider).fetchAppMarkdown(announcement);
  }

  Future<ServerAnnouncement> fetchServerAnnouncementDetail(int id) {
    return ref
        .read(announcementServiceProvider)
        .fetchServerAnnouncementDetail(id);
  }

  Future<AnnouncementState> _load() async {
    final service = ref.read(announcementServiceProvider);

    var appAnnouncements = const <AppAnnouncement>[];
    String? appErrorMessage;
    try {
      appAnnouncements = (await service.fetchAppManifest()).announcements;
    } catch (error) {
      appErrorMessage = _formatError(error);
    }

    var serverAnnouncements = const <ServerAnnouncement>[];
    String? serverErrorMessage;
    try {
      serverAnnouncements =
          (await service.fetchServerAnnouncements()).announcements;
    } catch (error) {
      serverErrorMessage = _formatError(error);
    }

    final readKeys = await ref.read(announcementReadStoreProvider).readKeys();
    final items = <AnnouncementListItem>[
      for (final announcement in appAnnouncements)
        AnnouncementListItem.app(
          announcement,
          isRead: readKeys.contains(announcement.readKey),
        ),
      for (final announcement in serverAnnouncements)
        AnnouncementListItem.server(
          announcement,
          summary: _previewFromHtml(announcement.contentHtml),
          isRead: readKeys.contains(announcement.readKey),
        ),
    ]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

    return AnnouncementState(
      items: items,
      appErrorMessage: appErrorMessage,
      serverErrorMessage: serverErrorMessage,
    );
  }
}

String _previewFromHtml(String html) {
  if (html.trim().isEmpty) {
    return '';
  }
  final text = html_parser.parseFragment(html).text?.trim() ?? '';
  if (text.length <= 80) {
    return text;
  }
  return '${text.substring(0, 80)}...';
}

String _formatError(Object error) {
  final message = error.toString().trim();
  if (message.startsWith('Exception:')) {
    return message.substring('Exception:'.length).trim();
  }
  return message;
}
