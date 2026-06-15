import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/features/announcements/announcement_detail_page.dart';
import 'package:novella/features/announcements/announcement_models.dart';
import 'package:novella/features/announcements/announcement_provider.dart';

class AnnouncementIconButton extends StatelessWidget {
  const AnnouncementIconButton({
    super.key,
    required this.hasUnread,
    required this.onPressed,
  });

  static const Key unreadDotKey = ValueKey<String>('announcement_unread_dot');

  final bool hasUnread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: '公告',
      icon: const Icon(Icons.campaign_outlined),
      onPressed: onPressed,
    );

    if (!hasUnread) {
      return button;
    }

    return Badge(key: unreadDotKey, child: button);
  }
}

class AnnouncementCenterPage extends ConsumerStatefulWidget {
  const AnnouncementCenterPage({super.key});

  @override
  ConsumerState<AnnouncementCenterPage> createState() =>
      _AnnouncementCenterPageState();
}

class _AnnouncementCenterPageState
    extends ConsumerState<AnnouncementCenterPage> {
  @override
  void initState() {
    super.initState();
    TelemetryService.instance.trackScreenView(
      TelemetryScreens.announcement,
      screenClass: 'AnnouncementCenterPage',
    );
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('公告'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed:
                () => ref
                    .read(announcementProvider.notifier)
                    .refresh(silent: false),
          ),
        ],
      ),
      body: announcements.when(
        loading: () => const Center(child: M3ELoadingIndicator()),
        error:
            (error, _) => _AnnouncementStateView(
              message: _formatError(error),
              actionLabel: '重试',
              onAction:
                  () => ref
                      .read(announcementProvider.notifier)
                      .refresh(silent: false),
            ),
        data:
            (state) => RefreshIndicator(
              onRefresh:
                  () => ref
                      .read(announcementProvider.notifier)
                      .refresh(silent: true),
              child:
                  state.items.isEmpty
                      ? const _AnnouncementStateView(message: '暂无公告')
                      : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: state.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = state.items[index];
                          return _AnnouncementTile(
                            item: item,
                            onTap: () {
                              AppRouteLauncher.pushDetail(
                                context,
                                (_) => AnnouncementDetailPage(item: item),
                              );
                            },
                          );
                        },
                      ),
            ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.item, required this.onTap});

  final AnnouncementListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          item.source == AnnouncementSource.app
              ? Icons.phone_iphone_rounded
              : Icons.public_rounded,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!item.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.summary.isEmpty ? _sourceLabel(item.source) : item.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${_formatDate(item.publishedAt)} · ${_sourceLabel(item.source)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _AnnouncementStateView extends StatelessWidget {
  const _AnnouncementStateView({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Center(child: Text(message)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}

String _sourceLabel(AnnouncementSource source) {
  switch (source) {
    case AnnouncementSource.app:
      return '应用公告';
    case AnnouncementSource.server:
      return '站点公告';
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String _formatError(Object error) {
  final message = error.toString().trim();
  return message.startsWith('Exception:')
      ? message.substring('Exception:'.length).trim()
      : message;
}
