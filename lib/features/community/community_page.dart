import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/core/layout/app_window_class.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/core/utils/time_utils.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/models/community.dart';
import 'package:novella/data/services/community_service.dart';
import 'package:novella/features/community/community_board_icon.dart';
import 'package:novella/features/community/community_compose_page.dart';
import 'package:novella/features/community/community_notification_page.dart';
import 'package:novella/features/community/community_thread_page.dart';
import 'package:novella/features/community/notification_unread_provider.dart';
import 'package:novella/features/settings/settings_page.dart';

class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => CommunityPageState();
}

class CommunityPageState extends ConsumerState<CommunityPage> {
  final CommunityService _communityService = CommunityService();

  bool _isTabActive = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _errorMessage;
  CommunityHomePayload? _payload;
  List<CommunityFeedItem> _feedItems = const <CommunityFeedItem>[];
  int _latestRequestId = 0;
  int _currentPage = 1;

  String _boardKey = 'all';
  String _subCategoryKey = '';
  CommunityFeedOrder _order = CommunityFeedOrder.latest;
  CommunityFeedScope _scope = CommunityFeedScope.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      refresh();
    });
  }

  void refresh() {
    unawaited(_loadCommunityHome());
    unawaited(
      ref
          .read(notificationUnreadCountProvider.notifier)
          .refreshCount(silent: true),
    );
  }

  void setTabActive(bool active) {
    if (_isTabActive == active) {
      return;
    }
    _isTabActive = active;
    if (active && _payload == null) {
      refresh();
    }
  }

  Future<void> _openComposePage() async {
    final createdThread =
        await AppRouteLauncher.pushDetail<CommunityThreadDetail>(
          context,
          (_) => const CommunityComposePage(),
        );
    if (!mounted || createdThread == null) {
      return;
    }

    unawaited(_loadCommunityHome());
    await _openThread(createdThread.id, createdThread.title);
  }

  Future<void> _openNotificationPage() async {
    await AppRouteLauncher.pushDetail(
      context,
      (_) => const CommunityNotificationPage(),
    );
    if (!mounted) {
      return;
    }
    await ref
        .read(notificationUnreadCountProvider.notifier)
        .refreshCount(silent: true);
  }

  Future<void> _openThread(int threadId, String title) {
    return AppRouteLauncher.pushDetail(
      context,
      (_) => CommunityThreadPage(threadId: threadId, initialTitle: title),
    );
  }

  CommunityListQuery _buildQuery(int page) {
    return CommunityListQuery(
      boardKey: _boardKey,
      subCategoryKey: _subCategoryKey,
      order: _order,
      scope: _scope,
      page: page,
      size: 6,
    );
  }

  bool _canApply(int requestId) {
    return mounted && _isTabActive && requestId == _latestRequestId;
  }

  Future<void> _loadCommunityHome() async {
    final requestId = ++_latestRequestId;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
    });

    try {
      final payload = await _communityService.getCommunityHome(
        query: _buildQuery(1),
      );
      if (!_canApply(requestId)) {
        return;
      }
      setState(() {
        _payload = payload;
        _feedItems = payload.feed;
        _subCategoryKey = payload.selectedSubCategoryKey;
        _currentPage = payload.feedPage.page;
      });
    } catch (error) {
      if (!_canApply(requestId) || isRequestCancelledError(error)) {
        return;
      }
      setState(() {
        _errorMessage = _formatError(error);
        _feedItems = const <CommunityFeedItem>[];
      });
    } finally {
      if (_canApply(requestId)) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadCommunityFeed({bool append = false}) async {
    if (_payload == null) {
      await _loadCommunityHome();
      return;
    }

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
      final feed = await _communityService.getCommunityFeed(
        query: _buildQuery(nextPage),
      );
      if (!_canApply(requestId) || _payload == null) {
        return;
      }
      setState(() {
        _payload = CommunityHomePayload(
          title: _payload!.title,
          subtitle: _payload!.subtitle,
          announcement: _payload!.announcement,
          announcementLink: _payload!.announcementLink,
          todayThreads: _payload!.todayThreads,
          onlineUserCount: _payload!.onlineUserCount,
          catalogBoards: _payload!.catalogBoards,
          boards: _payload!.boards,
          subCategories: feed.subCategories,
          selectedSubCategoryKey: feed.selectedSubCategoryKey,
          feed: feed.feed,
          feedPage: feed.feedPage,
          hotThreads: _payload!.hotThreads,
          activeUsers: _payload!.activeUsers,
        );
        _feedItems = append ? [..._feedItems, ...feed.feed] : feed.feed;
        _subCategoryKey = feed.selectedSubCategoryKey;
        _currentPage = feed.feedPage.page;
      });
    } catch (error) {
      if (!_canApply(requestId) || isRequestCancelledError(error)) {
        return;
      }
      setState(() {
        _errorMessage = _formatError(error);
        if (!append) {
          _feedItems = const <CommunityFeedItem>[];
        }
      });
    } finally {
      if (_canApply(requestId)) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _updateBoard(String boardKey) {
    if (_boardKey == boardKey) {
      return;
    }
    setState(() {
      _boardKey = boardKey;
      _subCategoryKey = '';
    });
    unawaited(_loadCommunityFeed());
  }

  void _updateSubCategory(String key) {
    if (_subCategoryKey == key) {
      return;
    }
    setState(() => _subCategoryKey = key);
    unawaited(_loadCommunityFeed());
  }

  void _updateOrder(CommunityFeedOrder order) {
    if (_order == order) {
      return;
    }
    setState(() => _order = order);
    unawaited(_loadCommunityFeed());
  }

  void _updateScope(CommunityFeedScope scope) {
    if (_scope == scope) {
      return;
    }
    setState(() => _scope = scope);
    unawaited(_loadCommunityFeed());
  }

  Future<void> _loadMore() async {
    final page = _payload?.feedPage;
    if (page == null || !page.hasMore || _loadingMore) {
      return;
    }
    await _loadCommunityFeed(append: true);
  }

  String _formatError(Object error) {
    final message = error.toString().trim();
    if (message.isEmpty) {
      return '加载社区失败，请稍后重试。';
    }
    return message.startsWith('Exception:')
        ? message.substring('Exception:'.length).trim()
        : message;
  }

  CommunityBoardSummary? _selectedBoardSummary() {
    final boards = _payload?.boards;
    if (boards == null) {
      return null;
    }
    for (final board in boards) {
      if (board.key == _boardKey) {
        return board;
      }
    }
    return null;
  }

  double _toolbarHeight(bool hasSubCategories) {
    return hasSubCategories ? 96 : 58;
  }

  Widget _buildHeader(int unreadCount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '社区',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: '发布帖子',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _openComposePage,
          ),
          _NotificationActionButton(
            unreadCount: unreadCount,
            onPressed: _openNotificationPage,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(
    CommunityHomePayload? payload,
    CommunityBoardSummary? selectedBoard,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = selectedBoard?.title ?? payload?.title ?? '社区讨论中心';
    final subtitle =
        selectedBoard?.description.isNotEmpty == true
            ? selectedBoard!.description
            : (payload?.subtitle ?? '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selectedBoard != null)
                  _BoardAccentBadge(
                    iconName: selectedBoard.icon,
                    fallbackText: selectedBoard.title,
                    accent: _boardAccentColor(context, selectedBoard.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryStatChip(
                  icon: Icons.auto_awesome_mosaic_rounded,
                  label: '今日新增',
                  value: '${payload?.todayThreads ?? 0}',
                ),
                _SummaryStatChip(
                  icon: Icons.wifi_tethering_rounded,
                  label: '在线',
                  value: '${payload?.onlineUserCount ?? 0}',
                ),
                if (selectedBoard != null && selectedBoard.heatLabel.isNotEmpty)
                  _SummaryStatChip(
                    icon: Icons.local_fire_department_outlined,
                    label: '热度',
                    value:
                        selectedBoard.heatLabel
                            .replaceFirst(RegExp(r'^热度\s*'), '')
                            .trim(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementBanner(CommunityHomePayload payload) {
    if (payload.announcement.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.64),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.campaign_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Web 端公告',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    payload.announcement,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            if (payload.announcementLink.isNotEmpty)
              Icon(
                Icons.north_east_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardStrip() {
    final boards = _payload?.boards ?? const <CommunityBoardSummary>[];
    if (boards.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedBoard = _selectedBoardSummary();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '板块',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedBoard != null
                            ? '当前：${_boardSelectionTitle(selectedBoard)}'
                            : '左右滑动切换讨论板块',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < boards.length; index++) ...[
                    _BoardFilterChip(
                      title: _boardSelectionTitle(boards[index]),
                      iconName: boards[index].icon,
                      fallbackText: boards[index].title,
                      accent: _boardAccentColor(context, boards[index].key),
                      selected: _boardKey == boards[index].key,
                      onTap: () => _updateBoard(boards[index].key),
                    ),
                    if (index != boards.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final colorScheme = Theme.of(context).colorScheme;
    final subCategories =
        _payload?.subCategories ?? const <CommunitySubCategorySummary>[];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              12,
              subCategories.isEmpty ? 8 : 6,
            ),
            child: Row(
              children: [
                _ToolbarCaption(label: '排序'),
                const SizedBox(width: 8),
                for (final option in const [
                  _ChipOption(CommunityFeedOrder.latest, '最新'),
                  _ChipOption(CommunityFeedOrder.hot, '最热'),
                  _ChipOption(CommunityFeedOrder.featured, '精选'),
                ]) ...[
                  _ToolbarPill(
                    label: option.label,
                    selected: _order == option.value,
                    onTap: () => _updateOrder(option.value),
                  ),
                  const SizedBox(width: 6),
                ],
                Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
                _ToolbarCaption(label: '范围'),
                const SizedBox(width: 8),
                for (final option in const [
                  _ChipOption(CommunityFeedScope.all, '全部'),
                  _ChipOption(CommunityFeedScope.today, '今天'),
                  _ChipOption(CommunityFeedScope.week, '本周'),
                ]) ...[
                  _ToolbarPill(
                    label: option.label,
                    selected: _scope == option.value,
                    onTap: () => _updateScope(option.value),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          if (subCategories.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _ToolbarPill(
                    label: '全部分类',
                    selected: _subCategoryKey.isEmpty,
                    onTap: () => _updateSubCategory(''),
                  ),
                  for (final item in subCategories) ...[
                    const SizedBox(width: 6),
                    _ToolbarPill(
                      label: '${item.label} ${item.count}',
                      selected: _subCategoryKey == item.key,
                      onTap: () => _updateSubCategory(item.key),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _boardSelectionTitle(CommunityBoardSummary board) {
    return board.key == 'all' ? '全部' : board.title;
  }

  Widget _buildErrorCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline_rounded, color: colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  '加载失败',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage ?? '数据暂时不可用。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: _loadCommunityHome,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前筛选下还没有帖子',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '可以切换板块、时间范围或子分类再看看。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedFooter() {
    if (_errorMessage != null && _feedItems.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 18, 12, 0),
        child: Center(child: M3ELoadingIndicator(size: 28)),
      );
    }

    if (_payload?.feedPage.hasMore ?? false) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        child: FilledButton.tonalIcon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more_rounded),
          label: const Text('加载更多'),
        ),
      );
    }

    if (_feedItems.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
        child: Center(
          child: Text(
            '已经看到这里了',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSecondaryModules(double bottomPadding) {
    final hotThreads = _payload?.hotThreads ?? const <CommunityHotRankItem>[];
    final activeUsers =
        _payload?.activeUsers ?? const <CommunityActiveUserItem>[];

    if (hotThreads.isEmpty && activeUsers.isEmpty) {
      return SizedBox(height: bottomPadding);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 18, 12, bottomPadding),
      child: Column(
        children: [
          if (hotThreads.isNotEmpty)
            _MiniSection(
              title: '热门讨论',
              icon: Icons.local_fire_department_outlined,
              child: Column(
                children: [
                  for (var index = 0; index < hotThreads.length; index++)
                    _MiniListRow(
                      title: hotThreads[index].title,
                      subtitle:
                          '${hotThreads[index].boardName} · 热度 ${hotThreads[index].heat} · ${_formatTimeLabel(hotThreads[index].publishedAt)}',
                      leading: _RankBadge(rank: index + 1),
                      onTap:
                          () => _openThread(
                            hotThreads[index].id,
                            hotThreads[index].title,
                          ),
                    ),
                ],
              ),
            ),
          if (hotThreads.isNotEmpty && activeUsers.isNotEmpty)
            const SizedBox(height: 10),
          if (activeUsers.isNotEmpty)
            _MiniSection(
              title: '活跃成员',
              icon: Icons.emoji_events_outlined,
              child: Column(
                children: [
                  for (final item in activeUsers)
                    _MiniListRow(
                      title: item.name,
                      subtitle:
                          item.summary.isNotEmpty ? item.summary : item.badge,
                      leading: _CommunityAvatar(
                        imageUrl: item.avatar,
                        fallbackText: item.name,
                        radius: 18,
                      ),
                      trailing: _ScoreBadge(score: item.score),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    final settings = ref.watch(settingsProvider);
    final unreadCount =
        ref.watch(notificationUnreadCountProvider).asData?.value ?? 0;
    final selectedBoard = _selectedBoardSummary();
    final hasSubCategories = (payload?.subCategories.isNotEmpty ?? false);
    final toolbarHeight = _toolbarHeight(hasSubCategories);
    final bottomPadding = appBottomContentPadding(
      context,
      useIOS26Style: settings.useIOS26Style,
    );

    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadCommunityHome,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(unreadCount)),
                if (_loading && payload == null)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: M3ELoadingIndicator()),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: _buildSummaryPanel(payload, selectedBoard),
                  ),
                  if (payload != null && payload.announcement.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildAnnouncementBanner(payload),
                    ),
                  SliverToBoxAdapter(child: _buildBoardStrip()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _PinnedToolbarDelegate(
                      height: toolbarHeight,
                      child: _buildToolbar(),
                    ),
                  ),
                  if (_loading && payload != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(minHeight: 3),
                        ),
                      ),
                    ),
                  if (_errorMessage != null && _feedItems.isEmpty)
                    SliverToBoxAdapter(child: _buildErrorCard())
                  else if (_feedItems.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyCard())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      sliver: SliverList.builder(
                        itemCount: _feedItems.length,
                        itemBuilder: (context, index) {
                          final item = _feedItems[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _feedItems.length - 1 ? 0 : 8,
                            ),
                            child: _CommunityFeedCard(
                              item: item,
                              onTap: () => _openThread(item.id, item.title),
                            ),
                          );
                        },
                      ),
                    ),
                  SliverToBoxAdapter(child: _buildFeedFooter()),
                  SliverToBoxAdapter(
                    child: _buildSecondaryModules(bottomPadding),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedToolbarDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedToolbarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 1 : 0,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.08),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedToolbarDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

class _NotificationActionButton extends StatelessWidget {
  const _NotificationActionButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: '通知中心',
      icon: const Icon(Icons.notifications_outlined),
      onPressed: onPressed,
    );

    if (unreadCount <= 0) {
      return button;
    }

    return Badge(
      label: Text(unreadCount > 99 ? '99+' : unreadCount.toString()),
      child: button,
    );
  }
}

class _SummaryStatChip extends StatelessWidget {
  const _SummaryStatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardAccentBadge extends StatelessWidget {
  const _BoardAccentBadge({
    required this.iconName,
    required this.fallbackText,
    required this.accent,
  });

  final String iconName;
  final String fallbackText;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CommunityBoardIconBadge(
      accent: accent,
      iconName: iconName,
      fallbackText: fallbackText,
      size: 42,
      iconSize: 18,
      borderRadius: 14,
    );
  }
}

class _BoardFilterChip extends StatelessWidget {
  const _BoardFilterChip({
    required this.title,
    required this.iconName,
    required this.fallbackText,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String iconName;
  final String fallbackText;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor =
        selected
            ? accent.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.42);
    final borderColor =
        selected
            ? accent.withValues(alpha: 0.28)
            : colorScheme.outlineVariant.withValues(alpha: 0.24);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 104),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CommunityBoardIconBadge(
                accent: accent,
                iconName: iconName,
                fallbackText: fallbackText,
                size: 30,
                iconSize: 14,
                borderRadius: 11,
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? accent : colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
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

class _ToolbarCaption extends StatelessWidget {
  const _ToolbarCaption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ToolbarPill extends StatelessWidget {
  const _ToolbarPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color:
          selected
              ? colorScheme.primary.withValues(alpha: 0.14)
              : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected
                      ? colorScheme.primary.withValues(alpha: 0.28)
                      : colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color:
                  selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommunityFeedCard extends StatelessWidget {
  const _CommunityFeedCard({required this.item, required this.onTap});

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommunityAvatar(
                imageUrl: item.authorAvatar,
                fallbackText: item.authorName,
                radius: 21,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.28,
                              ),
                              children: [
                                if (item.pinned)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.push_pin_rounded,
                                        size: 15,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                if (item.featured)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.star_rounded,
                                        size: 15,
                                        color: colorScheme.tertiary,
                                      ),
                                    ),
                                  ),
                                if (item.locked)
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.lock_outline_rounded,
                                        size: 14,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                TextSpan(text: item.title),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (item.replies > 0)
                          _CornerCountBadge(
                            icon: Icons.chat_bubble_outline_rounded,
                            value: _formatCount(item.replies),
                          ),
                      ],
                    ),
                    if (item.excerpt.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        item.excerpt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _BoardMetaChip(
                          label: item.boardName,
                          accent: _boardAccentColor(context, item.boardKey),
                        ),
                        if (item.subCategoryLabel.isNotEmpty)
                          _MetaChip(label: item.subCategoryLabel),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.authorName} · ${_formatTimeLabel(item.publishedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        _TinyStat(
                          icon: Icons.remove_red_eye_outlined,
                          value: _formatCount(item.views),
                        ),
                        const SizedBox(width: 10),
                        _TinyStat(
                          icon: Icons.favorite_border_rounded,
                          value: _formatCount(item.likes),
                        ),
                        if (item.favorites > 0) ...[
                          const SizedBox(width: 10),
                          _TinyStat(
                            icon: Icons.bookmark_border_rounded,
                            value: _formatCount(item.favorites),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar({
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

class _CornerCountBadge extends StatelessWidget {
  const _CornerCountBadge({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardMetaChip extends StatelessWidget {
  const _BoardMetaChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  const _TinyStat({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _MiniSection extends StatelessWidget {
  const _MiniSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MiniListRow extends StatelessWidget {
  const _MiniListRow({
    required this.title,
    required this.subtitle,
    required this.leading,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = switch (rank) {
      1 => const Color(0xFFF59E0B),
      2 => const Color(0xFFFB7185),
      3 => const Color(0xFF60A5FA),
      _ => colorScheme.primary,
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: TextStyle(color: accent, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChipOption<T> {
  const _ChipOption(this.value, this.label);

  final T value;
  final String label;
}

Color _boardAccentColor(BuildContext context, String key) {
  final colorScheme = Theme.of(context).colorScheme;
  return colorScheme.primary;
}

String _formatTimeLabel(DateTime? value) {
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
