import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/data/models/app_notification.dart';
import 'package:novella/data/services/notification_service.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:novella/features/community/community_thread_page.dart';
import 'package:novella/features/community/notification_unread_provider.dart';

class CommunityNotificationPage extends ConsumerStatefulWidget {
  const CommunityNotificationPage({super.key});

  @override
  ConsumerState<CommunityNotificationPage> createState() =>
      _CommunityNotificationPageState();
}

class _CommunityNotificationPageState
    extends ConsumerState<CommunityNotificationPage> {
  final NotificationService _notificationService = NotificationService();

  bool _loading = true;
  bool _loadingMore = false;
  String? _errorMessage;
  List<AppNotificationItem> _items = const <AppNotificationItem>[];
  int _currentPage = 1;
  int _totalPages = 1;
  int _latestRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadNotifications());
      }
    });
  }

  Future<void> _loadNotifications({bool append = false}) async {
    final requestId = ++_latestRequestId;
    final nextPage = append ? _currentPage + 1 : 1;

    setState(() {
      _errorMessage = null;
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
      }
    });

    try {
      final page = await _notificationService.getNotifications(page: nextPage);
      if (!mounted || requestId != _latestRequestId) {
        return;
      }

      setState(() {
        _items = append ? [..._items, ...page.items] : page.items;
        _currentPage = page.page;
        _totalPages = page.totalPages;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _latestRequestId ||
          isRequestCancelledError(error)) {
        return;
      }
      setState(() {
        _errorMessage = _formatError(error);
      });
    } finally {
      if (mounted && requestId == _latestRequestId) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openNotification(AppNotificationItem item) async {
    final objectId =
        item.extra.objectId > 0 ? item.extra.objectId : item.objectId;
    if (!item.isRead) {
      try {
        await _notificationService.markNotifications([item.id]);
        if (mounted) {
          setState(() {
            _items = _items
                .map((entry) {
                  if (entry.id != item.id) {
                    return entry;
                  }
                  return AppNotificationItem(
                    id: entry.id,
                    actor: entry.actor,
                    type: entry.type,
                    objectType: entry.objectType,
                    objectId: entry.objectId,
                    isRead: true,
                    createdAt: entry.createdAt,
                    extra: entry.extra,
                  );
                })
                .toList(growable: false);
          });
        }
      } catch (_) {}
      await ref
          .read(notificationUnreadCountProvider.notifier)
          .refreshCount(silent: true);
    }

    if (!mounted) {
      return;
    }

    switch (item.objectType) {
      case AppNotificationObjectType.communityThread:
        await AppRouteLauncher.pushDetail(
          context,
          (_) => CommunityThreadPage(
            threadId: objectId,
            initialTitle: item.extra.objectTitle,
            replyId: item.extra.replyId,
            parentReplyId: item.extra.parentReplyId,
          ),
        );
        return;
      case AppNotificationObjectType.book:
        await AppRouteLauncher.pushDetail(
          context,
          (_) => BookDetailPage(
            bookId: objectId,
            initialTitle: item.extra.objectTitle,
          ),
        );
        return;
      case AppNotificationObjectType.announcement:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('公告通知跳转将在下一步接入。')));
        return;
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _totalPages) {
      return;
    }
    await _loadNotifications(append: true);
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return '加载通知失败，请稍后重试。';
    }
    return message.startsWith('Exception:')
        ? message.substring('Exception:'.length).trim()
        : message;
  }

  String _typeLabel(AppNotificationItem item) {
    switch (item.type) {
      case AppNotificationType.comment:
        return '评论';
      case AppNotificationType.commentReply:
        return '评论回复';
      case AppNotificationType.communityThreadReply:
        return '帖子回复';
      case AppNotificationType.communityThreadChildReply:
        return '楼中楼回复';
    }
  }

  String _objectLabel(AppNotificationObjectType type) {
    switch (type) {
      case AppNotificationObjectType.book:
        return '书籍';
      case AppNotificationObjectType.announcement:
        return '公告';
      case AppNotificationObjectType.communityThread:
        return '社区帖子';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知中心')),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child:
            _loading && _items.isEmpty
                ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
                : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '通知中心已经接入真实数据源，当前支持查看列表、分页加载和标记已读。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_errorMessage != null && _items.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_errorMessage!),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: _loadNotifications,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_items.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('当前没有通知。'),
                        ),
                      )
                    else ...[
                      for (final item in _items) ...[
                        Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              item.extra.objectTitle.isEmpty
                                  ? '未命名通知对象'
                                  : item.extra.objectTitle,
                              style: TextStyle(
                                fontWeight:
                                    item.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _NotificationPill(
                                        label: _typeLabel(item),
                                      ),
                                      _NotificationPill(
                                        label: _objectLabel(item.objectType),
                                      ),
                                      _NotificationPill(
                                        label: item.isRead ? '已读' : '未读',
                                        accent: !item.isRead,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.extra.replyPreview.isNotEmpty
                                        ? item.extra.replyPreview
                                        : item.extra.preview,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    '${item.actor?.userName ?? '系统'} · ${_formatDate(item.createdAt)}',
                                  ),
                                ],
                              ),
                            ),
                            onTap: () => _openNotification(item),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_currentPage < _totalPages)
                        FilledButton.tonal(
                          onPressed: _loadMore,
                          child: const Text('加载更多'),
                        ),
                    ],
                  ],
                ),
      ),
    );
  }
}

class _NotificationPill extends StatelessWidget {
  const _NotificationPill({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            accent
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '未知时间';
  }
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
