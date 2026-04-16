import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/utils/time_utils.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/comment/widgets/comment_input_sheet.dart';
import 'package:novella/features/reader/shared/reader_text_sanitizer.dart';

class CommunityThreadPage extends StatefulWidget {
  const CommunityThreadPage({
    super.key,
    required this.threadId,
    this.initialTitle,
    this.replyId,
    this.parentReplyId,
  });

  final int threadId;
  final String? initialTitle;
  final int? replyId;
  final int? parentReplyId;

  @override
  State<CommunityThreadPage> createState() => _CommunityThreadPageState();
}

class _CommunityThreadPageState extends State<CommunityThreadPage> {
  final CommunityService _communityService = CommunityService();
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _replyAnchorKeys = <int, GlobalKey>{};

  bool _loading = true;
  bool _loadingMoreReplies = false;
  bool _postingReply = false;
  bool _togglingLike = false;
  bool _togglingFavorite = false;
  bool _resolvingReplyTarget = false;
  int? _highlightedReplyId;
  Timer? _replyHighlightTimer;
  String? _errorMessage;
  CommunityThreadDetail? _thread;
  int _latestRequestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadThread());
      }
    });
  }

  @override
  void didUpdateWidget(covariant CommunityThreadPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replyId != widget.replyId ||
        oldWidget.parentReplyId != widget.parentReplyId) {
      _resolvingReplyTarget = false;
      _scheduleReplyTargetNavigation();
    }
  }

  @override
  void dispose() {
    _replyHighlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThread({int replyPage = 1, bool append = false}) async {
    final requestId = ++_latestRequestId;
    setState(() {
      _errorMessage = null;
      if (append) {
        _loadingMoreReplies = true;
      } else {
        _loading = true;
      }
    });

    try {
      final detail = await _communityService.getCommunityThread(
        threadId: widget.threadId,
        replyPage: replyPage,
        replySize: 5,
        trackView: !append && replyPage == 1,
      );
      if (!mounted || requestId != _latestRequestId) {
        return;
      }

      setState(() {
        if (detail == null) {
          _thread = null;
          _errorMessage = '帖子不存在或已删除。';
          return;
        }

        if (append && _thread != null) {
          _thread = CommunityThreadDetail(
            id: detail.id,
            boardKey: detail.boardKey,
            boardName: detail.boardName,
            subCategoryKey: detail.subCategoryKey,
            subCategoryLabel: detail.subCategoryLabel,
            title: detail.title,
            excerpt: detail.excerpt,
            authorName: detail.authorName,
            authorAvatar: detail.authorAvatar,
            publishedAt: detail.publishedAt,
            replies: detail.replies,
            views: detail.views,
            heat: detail.heat,
            likes: detail.likes,
            favorites: detail.favorites,
            tags: detail.tags,
            featured: detail.featured,
            pinned: detail.pinned,
            locked: detail.locked,
            liked: detail.liked,
            favorited: detail.favorited,
            bodyHtml: detail.bodyHtml,
            repliesPage: detail.repliesPage,
            replyItems: [..._thread!.replyItems, ...detail.replyItems],
            relatedThreads: detail.relatedThreads,
          );
        } else {
          _thread = detail;
        }
      });

      if (mounted && requestId == _latestRequestId && _thread != null) {
        _scheduleReplyTargetNavigation();
      }
    } catch (error) {
      if (!mounted || requestId != _latestRequestId) {
        return;
      }
      setState(() {
        _errorMessage = _formatError(error);
      });
    } finally {
      if (mounted && requestId == _latestRequestId) {
        setState(() {
          _loading = false;
          _loadingMoreReplies = false;
        });
      }
    }
  }

  GlobalKey _replyAnchorKey(int replyId) {
    return _replyAnchorKeys.putIfAbsent(replyId, GlobalKey.new);
  }

  CommunityThreadReply? _findReplyById(
    List<CommunityThreadReply> replies,
    int replyId,
  ) {
    for (final reply in replies) {
      if (reply.id == replyId) {
        return reply;
      }
      final childMatch = _findReplyById(reply.childReplies, replyId);
      if (childMatch != null) {
        return childMatch;
      }
    }
    return null;
  }

  void _scheduleReplyTargetNavigation() {
    if (_resolvingReplyTarget || !mounted || _thread == null) {
      return;
    }
    final targetId = widget.replyId ?? widget.parentReplyId;
    if (targetId == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _thread == null) {
        return;
      }
      unawaited(_resolveReplyTargetNavigation());
    });
  }

  Future<void> _resolveReplyTargetNavigation() async {
    if (_resolvingReplyTarget || !mounted || _thread == null) {
      return;
    }

    final replyId = widget.replyId;
    final parentReplyId = widget.parentReplyId;
    final fallbackTargetId = replyId ?? parentReplyId;
    if (fallbackTargetId == null) {
      return;
    }

    _resolvingReplyTarget = true;
    try {
      if (replyId != null &&
          parentReplyId != null &&
          replyId != parentReplyId) {
        final parentReply = await _ensureTopLevelReplyLoaded(parentReplyId);
        if (!mounted || parentReply == null) {
          return;
        }
        final targetReply = await _ensureChildReplyLoaded(
          parentReplyId: parentReply.id,
          targetReplyId: replyId,
        );
        _scrollToReplyLater((targetReply ?? parentReply).id);
        return;
      }

      final targetReply = await _ensureTopLevelReplyLoaded(fallbackTargetId);
      if (targetReply != null) {
        _scrollToReplyLater(targetReply.id);
      }
    } finally {
      _resolvingReplyTarget = false;
    }
  }

  Future<CommunityThreadReply?> _ensureTopLevelReplyLoaded(int replyId) async {
    while (mounted && _thread != null) {
      final current = _findReplyById(_thread!.replyItems, replyId);
      if (current != null) {
        return current;
      }

      if (!_thread!.repliesPage.hasMore) {
        return null;
      }

      await _loadThread(replyPage: _thread!.repliesPage.page + 1, append: true);
    }
    return null;
  }

  Future<CommunityThreadReply?> _ensureChildReplyLoaded({
    required int parentReplyId,
    required int targetReplyId,
  }) async {
    while (mounted && _thread != null) {
      final parentReply = _findReplyById(_thread!.replyItems, parentReplyId);
      if (parentReply == null) {
        return null;
      }

      final targetReply = _findReplyById(
        parentReply.childReplies,
        targetReplyId,
      );
      if (targetReply != null) {
        return targetReply;
      }

      if (!parentReply.childPage.hasMore) {
        return parentReply;
      }

      final payload = await _communityService.getCommunityReplyChildren(
        GetCommunityReplyChildrenRequest(
          threadId: widget.threadId,
          parentReplyId: parentReply.id,
          page: parentReply.childPage.page + 1,
          size:
              parentReply.childPage.size == 0 ? 3 : parentReply.childPage.size,
        ),
      );
      if (!mounted || _thread == null) {
        return null;
      }

      setState(() {
        _thread = _copyThreadWithReplies(
          _thread!,
          _updateReply(_thread!.replyItems, parentReply.id, (current) {
            return CommunityThreadReply(
              id: current.id,
              authorName: current.authorName,
              authorBadge: current.authorBadge,
              authorAvatar: current.authorAvatar,
              publishedAt: current.publishedAt,
              content: current.content,
              likes: current.likes,
              liked: current.liked,
              replyTo: current.replyTo,
              childReplies: [...current.childReplies, ...payload.items],
              childPage: payload.page,
            );
          }),
        );
      });
    }
    return null;
  }

  void _scrollToReplyLater(int replyId) {
    _flashReplyHighlight(replyId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_scrollToReply(replyId));
    });
  }

  void _flashReplyHighlight(int replyId) {
    if (!mounted) {
      return;
    }
    _replyHighlightTimer?.cancel();
    setState(() {
      _highlightedReplyId = replyId;
    });
    _replyHighlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (!mounted || _highlightedReplyId != replyId) {
        return;
      }
      setState(() {
        _highlightedReplyId = null;
      });
    });
  }

  Future<void> _scrollToReply(int replyId) async {
    final anchorContext = _replyAnchorKeys[replyId]?.currentContext;
    if (anchorContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      anchorContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }

  Future<void> _toggleLike() async {
    final thread = _thread;
    if (thread == null || _togglingLike) {
      return;
    }
    setState(() => _togglingLike = true);
    try {
      final result = await _communityService.toggleThreadLike(thread.id);
      if (!mounted || _thread == null) {
        return;
      }
      setState(() {
        _thread = CommunityThreadDetail(
          id: thread.id,
          boardKey: thread.boardKey,
          boardName: thread.boardName,
          subCategoryKey: thread.subCategoryKey,
          subCategoryLabel: thread.subCategoryLabel,
          title: thread.title,
          excerpt: thread.excerpt,
          authorName: thread.authorName,
          authorAvatar: thread.authorAvatar,
          publishedAt: thread.publishedAt,
          replies: thread.replies,
          views: thread.views,
          heat: thread.heat,
          likes: result.likes,
          favorites: thread.favorites,
          tags: thread.tags,
          featured: thread.featured,
          pinned: thread.pinned,
          locked: thread.locked,
          liked: result.liked,
          favorited: thread.favorited,
          bodyHtml: thread.bodyHtml,
          repliesPage: thread.repliesPage,
          replyItems: thread.replyItems,
          relatedThreads: thread.relatedThreads,
        );
      });
    } catch (error) {
      _showSnack(_formatError(error));
    } finally {
      if (mounted) {
        setState(() => _togglingLike = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final thread = _thread;
    if (thread == null || _togglingFavorite) {
      return;
    }
    setState(() => _togglingFavorite = true);
    try {
      final result = await _communityService.toggleThreadFavorite(thread.id);
      if (!mounted || _thread == null) {
        return;
      }
      setState(() {
        _thread = CommunityThreadDetail(
          id: thread.id,
          boardKey: thread.boardKey,
          boardName: thread.boardName,
          subCategoryKey: thread.subCategoryKey,
          subCategoryLabel: thread.subCategoryLabel,
          title: thread.title,
          excerpt: thread.excerpt,
          authorName: thread.authorName,
          authorAvatar: thread.authorAvatar,
          publishedAt: thread.publishedAt,
          replies: thread.replies,
          views: thread.views,
          heat: thread.heat,
          likes: thread.likes,
          favorites: result.favorites,
          tags: thread.tags,
          featured: thread.featured,
          pinned: thread.pinned,
          locked: thread.locked,
          liked: thread.liked,
          favorited: result.favorited,
          bodyHtml: thread.bodyHtml,
          repliesPage: thread.repliesPage,
          replyItems: thread.replyItems,
          relatedThreads: thread.relatedThreads,
        );
      });
    } catch (error) {
      _showSnack(_formatError(error));
    } finally {
      if (mounted) {
        setState(() => _togglingFavorite = false);
      }
    }
  }

  Future<void> _openReplySheet({CommunityThreadReply? reply}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => CommentInputSheet(
            hintText: reply == null ? '回复帖子...' : '回复 ${reply.authorName}',
            onSubmit: (content) {
              unawaited(_postReply(content, replyTo: reply));
            },
          ),
    );
  }

  Future<void> _postReply(
    String content, {
    CommunityThreadReply? replyTo,
  }) async {
    if (_postingReply) {
      return;
    }
    setState(() => _postingReply = true);
    try {
      await _communityService.createCommunityReply(
        CreateCommunityReplyRequest(
          threadId: widget.threadId,
          content: content,
          replyToId: replyTo?.id,
        ),
      );
      await _loadThread();
      _showSnack('回复已发布。');
    } catch (error) {
      _showSnack(_formatError(error));
    } finally {
      if (mounted) {
        setState(() => _postingReply = false);
      }
    }
  }

  Future<void> _toggleReplyLike(CommunityThreadReply reply) async {
    try {
      final result = await _communityService.toggleReplyLike(reply.id);
      if (!mounted || _thread == null) {
        return;
      }
      setState(() {
        _thread = _copyThreadWithReplies(
          _thread!,
          _updateReply(_thread!.replyItems, reply.id, (current) {
            return CommunityThreadReply(
              id: current.id,
              authorName: current.authorName,
              authorBadge: current.authorBadge,
              authorAvatar: current.authorAvatar,
              publishedAt: current.publishedAt,
              content: current.content,
              likes: result.likes,
              liked: result.liked,
              replyTo: current.replyTo,
              childReplies: current.childReplies,
              childPage: current.childPage,
            );
          }),
        );
      });
    } catch (error) {
      _showSnack(_formatError(error));
    }
  }

  Future<void> _loadMoreChildReplies(CommunityThreadReply parent) async {
    try {
      final payload = await _communityService.getCommunityReplyChildren(
        GetCommunityReplyChildrenRequest(
          threadId: widget.threadId,
          parentReplyId: parent.id,
          page: parent.childPage.page + 1,
          size: parent.childPage.size == 0 ? 3 : parent.childPage.size,
        ),
      );
      if (!mounted || _thread == null) {
        return;
      }
      setState(() {
        _thread = _copyThreadWithReplies(
          _thread!,
          _updateReply(_thread!.replyItems, parent.id, (current) {
            return CommunityThreadReply(
              id: current.id,
              authorName: current.authorName,
              authorBadge: current.authorBadge,
              authorAvatar: current.authorAvatar,
              publishedAt: current.publishedAt,
              content: current.content,
              likes: current.likes,
              liked: current.liked,
              replyTo: current.replyTo,
              childReplies: [...current.childReplies, ...payload.items],
              childPage: payload.page,
            );
          }),
        );
      });
    } catch (error) {
      _showSnack(_formatError(error));
    }
  }

  CommunityThreadDetail _copyThreadWithReplies(
    CommunityThreadDetail thread,
    List<CommunityThreadReply> replies,
  ) {
    return CommunityThreadDetail(
      id: thread.id,
      boardKey: thread.boardKey,
      boardName: thread.boardName,
      subCategoryKey: thread.subCategoryKey,
      subCategoryLabel: thread.subCategoryLabel,
      title: thread.title,
      excerpt: thread.excerpt,
      authorName: thread.authorName,
      authorAvatar: thread.authorAvatar,
      publishedAt: thread.publishedAt,
      replies: thread.replies,
      views: thread.views,
      heat: thread.heat,
      likes: thread.likes,
      favorites: thread.favorites,
      tags: thread.tags,
      featured: thread.featured,
      pinned: thread.pinned,
      locked: thread.locked,
      liked: thread.liked,
      favorited: thread.favorited,
      bodyHtml: thread.bodyHtml,
      repliesPage: thread.repliesPage,
      replyItems: replies,
      relatedThreads: thread.relatedThreads,
    );
  }

  List<CommunityThreadReply> _updateReply(
    List<CommunityThreadReply> replies,
    int replyId,
    CommunityThreadReply Function(CommunityThreadReply current) update,
  ) {
    return replies
        .map((reply) {
          if (reply.id == replyId) {
            return update(reply);
          }
          if (reply.childReplies.isEmpty) {
            return reply;
          }
          return CommunityThreadReply(
            id: reply.id,
            authorName: reply.authorName,
            authorBadge: reply.authorBadge,
            authorAvatar: reply.authorAvatar,
            publishedAt: reply.publishedAt,
            content: reply.content,
            likes: reply.likes,
            liked: reply.liked,
            replyTo: reply.replyTo,
            childReplies: _updateReply(reply.childReplies, replyId, update),
            childPage: reply.childPage,
          );
        })
        .toList(growable: false);
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return '加载帖子失败，请稍后重试。';
    }
    return message.startsWith('Exception:')
        ? message.substring('Exception:'.length).trim()
        : message;
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    final colorScheme = Theme.of(context).colorScheme;
    final appBarTitle =
        thread?.boardName.isNotEmpty == true
            ? thread!.boardName
            : (widget.initialTitle ?? '帖子详情');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            _postingReply || (thread?.locked ?? false)
                ? null
                : () => _openReplySheet(),
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        foregroundColor: colorScheme.primary,
        icon: const Icon(Icons.reply_rounded),
        label: Text(_postingReply ? '发送中' : '回复'),
      ),
      body:
          _loading && thread == null
              ? const Center(child: M3ELoadingIndicator())
              : _errorMessage != null && thread == null
              ? _ThreadStateCard(
                message: _errorMessage!,
                actionLabel: '重试',
                onAction: _loadThread,
              )
              : RefreshIndicator(
                onRefresh: _loadThread,
                child: ListView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  children: [
                    _ThreadMainPost(
                      thread: thread!,
                      html: thread.bodyHtml,
                      onLike: _toggleLike,
                      onFavorite: _toggleFavorite,
                      liking: _togglingLike,
                      favoriting: _togglingFavorite,
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: '回复',
                      subtitle: '${thread.repliesPage.total} 条讨论',
                    ),
                    const SizedBox(height: 8),
                    if (thread.replyItems.isEmpty)
                      const _EmptyRepliesCard()
                    else
                      for (final reply in thread.replyItems) ...[
                        _ReplyCard(
                          anchorKey: _replyAnchorKey(reply.id),
                          reply: reply,
                          highlightedReplyId: _highlightedReplyId,
                          onReply: (targetReply) {
                            unawaited(_openReplySheet(reply: targetReply));
                          },
                          onLike: () => _toggleReplyLike(reply),
                          childReplyKeyBuilder: _replyAnchorKey,
                          onLoadMoreChildren:
                              reply.childPage.hasMore
                                  ? () => _loadMoreChildReplies(reply)
                                  : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                    if (_loadingMoreReplies)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (thread.repliesPage.hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: FilledButton.tonalIcon(
                          onPressed:
                              () => _loadThread(
                                replyPage: thread.repliesPage.page + 1,
                                append: true,
                              ),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: const Text('加载更多回复'),
                        ),
                      ),
                    if (thread.relatedThreads.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      const _SectionHeader(
                        title: '相关讨论',
                        subtitle: '继续从这个话题往下读',
                      ),
                      const SizedBox(height: 8),
                      for (final related in thread.relatedThreads) ...[
                        _RelatedThreadCard(
                          item: related,
                          onTap:
                              () => AppRouteLauncher.pushReplacementDetail(
                                context,
                                (_) => CommunityThreadPage(
                                  threadId: related.id,
                                  initialTitle: related.title,
                                ),
                              ),
                        ),
                        if (related != thread.relatedThreads.last)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
              ),
    );
  }
}

class _ThreadStateCard extends StatelessWidget {
  const _ThreadStateCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _SurfacePanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadMainPost extends StatelessWidget {
  const _ThreadMainPost({
    required this.thread,
    required this.html,
    required this.onLike,
    required this.onFavorite,
    required this.liking,
    required this.favoriting,
  });

  final CommunityThreadDetail thread;
  final String html;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final bool liking;
  final bool favoriting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _boardAccentColor(context, thread.boardKey);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BoardBadge(label: thread.boardName, accent: accent),
                    if (thread.subCategoryLabel.isNotEmpty)
                      _ThreadTag(label: thread.subCategoryLabel),
                    if (thread.featured)
                      const _ThreadTag(
                        label: '精选',
                        icon: Icons.star_rounded,
                        accent: true,
                      ),
                    if (thread.pinned)
                      const _ThreadTag(
                        label: '置顶',
                        icon: Icons.push_pin_rounded,
                        accent: true,
                      ),
                    if (thread.locked)
                      const _ThreadTag(
                        label: '已锁定',
                        icon: Icons.lock_outline_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ForumAvatar(
                      imageUrl: thread.authorAvatar,
                      fallbackText: thread.authorName,
                      radius: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.authorName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatThreadTime(thread.publishedAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _InlineMetaItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      value: _formatCount(thread.replies),
                      label: '回复',
                    ),
                    _InlineMetaItem(
                      icon: Icons.remove_red_eye_outlined,
                      value: _formatCount(thread.views),
                      label: '浏览',
                    ),
                    _InlineMetaItem(
                      icon: Icons.favorite_border_rounded,
                      value: _formatCount(thread.likes),
                      label: '点赞',
                    ),
                    _InlineMetaItem(
                      icon: Icons.bookmark_border_rounded,
                      value: _formatCount(thread.favorites),
                      label: '收藏',
                    ),
                    if (thread.heat > 0)
                      _InlineMetaItem(
                        icon: Icons.local_fire_department_outlined,
                        value: _formatCount(thread.heat),
                        label: '热度',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionPill(
                        label: thread.liked ? '已点赞' : '点赞',
                        icon:
                            thread.liked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                        selected: thread.liked,
                        busy: liking,
                        onTap: onLike,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionPill(
                        label: thread.favorited ? '已收藏' : '收藏',
                        icon:
                            thread.favorited
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                        selected: thread.favorited,
                        busy: favoriting,
                        onTap: onFavorite,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: HtmlWidget(
              sanitizeReaderHtmlTextNodes(html, const {}),
              textStyle: theme.textTheme.bodyLarge?.copyWith(height: 1.72),
              customStylesBuilder: (element) {
                switch (element.localName) {
                  case 'body':
                    return {'margin': '0', 'padding': '0'};
                  case 'p':
                    return {'margin': '0 0 0.8em 0', 'line-height': '1.72'};
                  case 'img':
                    return {'max-width': '100%', 'height': 'auto'};
                  case 'blockquote':
                    return {
                      'margin': '0.9em 0',
                      'padding': '0.65em 0.9em',
                      'border-left': '3px solid #94a3b8',
                      'background': '#00000008',
                    };
                  default:
                    return null;
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetaItem extends StatelessWidget {
  const _InlineMetaItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.84),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.54),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRepliesCard extends StatelessWidget {
  const _EmptyRepliesCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _SurfacePanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.forum_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '当前还没有回复，来留下第一条吧。',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.anchorKey,
    required this.reply,
    required this.highlightedReplyId,
    required this.onReply,
    required this.onLike,
    required this.childReplyKeyBuilder,
    this.onLoadMoreChildren,
  });

  final GlobalKey anchorKey;
  final CommunityThreadReply reply;
  final int? highlightedReplyId;
  final ValueChanged<CommunityThreadReply> onReply;
  final VoidCallback onLike;
  final GlobalKey Function(int replyId) childReplyKeyBuilder;
  final VoidCallback? onLoadMoreChildren;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isHighlighted = highlightedReplyId == reply.id;

    return AnimatedContainer(
      key: anchorKey,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color:
            isHighlighted
                ? colorScheme.primaryContainer.withValues(alpha: 0.18)
                : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              isHighlighted
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isHighlighted ? 1.2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ForumAvatar(
                  imageUrl: reply.authorAvatar,
                  fallbackText: reply.authorName,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reply.authorName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (reply.authorBadge.isNotEmpty)
                            _ThreadTag(label: reply.authorBadge),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reply.replyTo != null
                            ? '回复 ${reply.replyTo!.authorName} · ${_formatThreadTime(reply.publishedAt)}'
                            : _formatThreadTime(reply.publishedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              reply.content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.48),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ReplyActionChip(
                  icon:
                      reply.liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                  label: _formatCount(reply.likes),
                  active: reply.liked,
                  onTap: onLike,
                ),
                const SizedBox(width: 8),
                _ReplyActionChip(
                  icon: Icons.reply_rounded,
                  label: '回复',
                  onTap: () => onReply(reply),
                ),
              ],
            ),
            if (reply.childReplies.isNotEmpty ||
                onLoadMoreChildren != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.72,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final child in reply.childReplies) ...[
                      _ChildReplyCard(
                        anchorKey: childReplyKeyBuilder(child.id),
                        reply: child,
                        highlighted: highlightedReplyId == child.id,
                        onReply: () => onReply(child),
                      ),
                      if (child != reply.childReplies.last)
                        Divider(
                          height: 16,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.28,
                          ),
                        ),
                    ],
                    if (onLoadMoreChildren != null)
                      Padding(
                        padding: EdgeInsets.only(
                          top: reply.childReplies.isEmpty ? 0 : 6,
                        ),
                        child: TextButton.icon(
                          onPressed: onLoadMoreChildren,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            reply.childReplies.isEmpty ? '加载楼中楼' : '加载更多楼中楼',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChildReplyCard extends StatelessWidget {
  const _ChildReplyCard({
    required this.anchorKey,
    required this.reply,
    required this.highlighted,
    required this.onReply,
  });

  final GlobalKey anchorKey;
  final CommunityThreadReply reply;
  final bool highlighted;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      key: anchorKey,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color:
            highlighted
                ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border:
            highlighted
                ? Border.all(color: colorScheme.primary, width: 1.1)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.replyTo != null
                ? '${reply.authorName} 回复 ${reply.replyTo!.authorName}'
                : reply.authorName,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reply.content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.42),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _formatThreadTime(reply.publishedAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onReply,
                icon: const Icon(Icons.reply_rounded, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RelatedThreadCard extends StatelessWidget {
  const _RelatedThreadCard({required this.item, required this.onTap});

  final CommunityFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BoardBadge(
                    label: item.boardName,
                    accent: _boardAccentColor(context, item.boardKey),
                  ),
                  if (item.subCategoryLabel.isNotEmpty)
                    _ThreadTag(label: item.subCategoryLabel),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.28,
                ),
              ),
              if (item.excerpt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.excerpt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.authorName} · ${_formatThreadTime(item.publishedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _MetricBubble(
                    icon: Icons.chat_bubble_outline_rounded,
                    value: _formatCount(item.replies),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SurfacePanel extends StatelessWidget {
  const _SurfacePanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _BoardBadge extends StatelessWidget {
  const _BoardBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ThreadTag extends StatelessWidget {
  const _ThreadTag({required this.label, this.icon, this.accent = false});

  final String label;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        accent
            ? colorScheme.primaryContainer.withValues(alpha: 0.76)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.75);
    final foreground =
        accent ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: foreground.withValues(alpha: accent ? 0.2 : 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBubble extends StatelessWidget {
  const _MetricBubble({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.68)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.62);
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else
                Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyActionChip extends StatelessWidget {
  const _ReplyActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        active
            ? colorScheme.primaryContainer.withValues(alpha: 0.76)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.75);
    final foreground =
        active ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumAvatar extends StatelessWidget {
  const _ForumAvatar({
    required this.imageUrl,
    required this.fallbackText,
    this.radius = 20,
  });

  final String imageUrl;
  final String fallbackText;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      child: Text(
        fallbackText.isNotEmpty ? fallbackText.characters.first : '?',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
          color: colorScheme.onSurface,
        ),
      ),
    );

    if (imageUrl.isEmpty) {
      return SizedBox(width: radius * 2, height: radius * 2, child: fallback);
    }

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        memCacheWidth: 120,
        imageBuilder:
            (context, provider) =>
                CircleAvatar(radius: radius, backgroundImage: provider),
        placeholder: (context, url) => fallback,
        errorWidget: (context, url, error) => fallback,
      ),
    );
  }
}

Color _boardAccentColor(BuildContext context, String key) {
  final colorScheme = Theme.of(context).colorScheme;
  final palette = <Color>[
    colorScheme.primary,
    colorScheme.secondary,
    colorScheme.tertiary,
    Color.lerp(colorScheme.primary, colorScheme.secondary, 0.45)!,
    Color.lerp(colorScheme.secondary, colorScheme.tertiary, 0.45)!,
  ];

  var hash = 0;
  for (final codeUnit in key.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}

String _formatThreadTime(DateTime? value) {
  if (value == null) {
    return '未知时间';
  }

  final local = value.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.inDays < 45) {
    return TimeUtils.formatRelativeTime(local);
  }
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _formatCount(int value) {
  if (value >= 100000) {
    return '${(value / 10000).round()}万';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(1).replaceAll('.0', '')}万';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
  }
  return value.toString();
}
