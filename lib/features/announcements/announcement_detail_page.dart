import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/features/announcements/announcement_models.dart';
import 'package:novella/features/announcements/announcement_provider.dart';

class AnnouncementDetailPage extends ConsumerStatefulWidget {
  const AnnouncementDetailPage({super.key, required this.item})
    : serverId = null,
      initialTitle = null;

  const AnnouncementDetailPage.server({
    super.key,
    required this.serverId,
    this.initialTitle,
  }) : item = null;

  final AnnouncementListItem? item;
  final int? serverId;
  final String? initialTitle;

  @override
  ConsumerState<AnnouncementDetailPage> createState() =>
      _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState
    extends ConsumerState<AnnouncementDetailPage> {
  Future<String>? _appMarkdownFuture;
  Future<ServerAnnouncement>? _serverDetailFuture;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item?.source == AnnouncementSource.app &&
        item?.appAnnouncement != null) {
      _appMarkdownFuture = ref
          .read(announcementProvider.notifier)
          .fetchAppMarkdown(item!.appAnnouncement!);
    } else {
      final id = item?.serverId ?? widget.serverId;
      if (id != null) {
        _serverDetailFuture = ref
            .read(announcementProvider.notifier)
            .fetchServerAnnouncementDetail(id);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final currentItem = widget.item;
      if (currentItem != null) {
        if (currentItem.source == AnnouncementSource.app &&
            currentItem.required) {
          return;
        }
        unawaited(
          ref.read(announcementProvider.notifier).markRead(currentItem),
        );
        return;
      }
      final serverId = widget.serverId;
      if (serverId != null) {
        unawaited(
          ref
              .read(announcementProvider.notifier)
              .markRead(
                AnnouncementListItem.server(
                  ServerAnnouncement(
                    id: serverId,
                    title: widget.initialTitle ?? '公告',
                    createdAt: DateTime.fromMillisecondsSinceEpoch(
                      0,
                      isUtc: true,
                    ),
                    contentHtml: '',
                  ),
                  summary: '',
                  isRead: false,
                ),
              ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = item?.title ?? widget.initialTitle ?? '公告详情';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body:
          item?.source == AnnouncementSource.app
              ? _buildAppDetail(context, item!.appAnnouncement!)
              : _buildServerDetail(context),
    );
  }

  Widget _buildAppDetail(BuildContext context, AppAnnouncement announcement) {
    final future = _appMarkdownFuture;
    if (future == null) {
      return const _DetailError(message: '公告内容不可用');
    }

    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: M3ELoadingIndicator());
        }
        if (snapshot.hasError) {
          return _DetailError(message: _formatError(snapshot.error!));
        }
        return Markdown(
          data: snapshot.data ?? '',
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        );
      },
    );
  }

  Widget _buildServerDetail(BuildContext context) {
    final future = _serverDetailFuture;
    if (future == null) {
      return const _DetailError(message: '公告内容不可用');
    }

    return FutureBuilder<ServerAnnouncement>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: M3ELoadingIndicator());
        }
        if (snapshot.hasError) {
          return _DetailError(message: _formatError(snapshot.error!));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: HtmlWidget(snapshot.data?.contentHtml ?? ''),
        );
      },
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

String _formatError(Object error) {
  final message = error.toString().trim();
  return message.startsWith('Exception:')
      ? message.substring('Exception:'.length).trim()
      : message;
}
