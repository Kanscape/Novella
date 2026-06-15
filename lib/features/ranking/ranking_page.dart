import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/layout/app_window_class.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_content_filter.dart';
import 'package:novella/data/services/book_service.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/features/settings/settings_page.dart';
import 'package:novella/src/widgets/book_cover_card.dart';
import 'package:novella/src/widgets/book_grid_title.dart';
import 'package:novella/src/widgets/book_type_badge.dart';

class RankingPage extends ConsumerStatefulWidget {
  final String initialType; // 'daily'（日）, 'weekly'（周）, 'monthly'（月）

  const RankingPage({super.key, this.initialType = 'weekly'});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage>
    with SingleTickerProviderStateMixin {
  final _logger = Logger('RankingPage');
  final _bookService = BookService();
  final _scrollController = ScrollController();

  late TabController _tabController;
  final Map<String, List<Book>> _cache = {};
  final Map<String, int> _displayedCount = {};
  final Set<String> _requestedCacheKeys = {};
  bool _loading = true;
  bool _loadingMore = false;

  static const _tabs = [
    ('daily', '日榜', 1),
    ('weekly', '周榜', 7),
    ('monthly', '月榜', 31),
  ];
  static const int _pageSize = 24;

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabs.indexWhere((t) => t.$1 == widget.initialType);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 1,
    );
    TelemetryService.instance.trackScreenView(
      TelemetryScreens.ranking,
      screenClass: 'RankingPage',
      properties: {TelemetryProperties.homeRankType: _currentType},
    );
    _tabController.addListener(_onTabChange);
    _scrollController.addListener(_onScroll);
    _fetchRanking();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (!_tabController.indexIsChanging) {
      _fetchRanking();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  String get _currentType => _tabs[_tabController.index].$1;
  int get _currentDays => _tabs[_tabController.index].$3;

  String _cacheKey(String type, AppSettings settings) {
    return '$type:${settings.ignoreJapanese}:${settings.ignoreAI}:${settings.ignoreLevel6}';
  }

  Future<void> _fetchRanking({bool refresh = false}) async {
    final settings = ref.read(settingsProvider);
    final currentCacheKey = _cacheKey(_currentType, settings);
    _requestedCacheKeys.add(currentCacheKey);

    if (!refresh && _cache.containsKey(currentCacheKey)) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      var books = await _bookService.getRank(_currentDays);
      books = filterBooksByContentSettings(
        books,
        ignoreJapanese: settings.ignoreJapanese,
        ignoreAI: settings.ignoreAI,
        ignoreLevel6: settings.ignoreLevel6,
      );
      _cache[currentCacheKey] = books;
      _displayedCount[currentCacheKey] = _pageSize.clamp(0, books.length);
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      _logger.severe('Failed to fetch ranking: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('加载失败')));
      }
    }
  }

  void _loadMore() {
    final settings = ref.read(settingsProvider);
    final currentCacheKey = _cacheKey(_currentType, settings);
    final allBooks = _cache[currentCacheKey] ?? [];
    final currentCount = _displayedCount[currentCacheKey] ?? 0;

    if (_loadingMore || currentCount >= allBooks.length) return;

    setState(() => _loadingMore = true);

    // 模拟短暂延迟提升体验
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          final newCount = (currentCount + _pageSize).clamp(0, allBooks.length);
          _displayedCount[currentCacheKey] = newCount;
          _loadingMore = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);
    final currentCacheKey = _cacheKey(_currentType, settings);
    final hasCachedCurrentRanking = _cache.containsKey(currentCacheKey);
    final allBooks = _cache[currentCacheKey] ?? [];
    final displayCount = _displayedCount[currentCacheKey] ?? 0;
    final displayBooks = allBooks.take(displayCount).toList();
    final hasMore = displayCount < allBooks.length;

    if (!_loading &&
        !hasCachedCurrentRanking &&
        !_requestedCacheKeys.contains(currentCacheKey)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_loading) {
          _fetchRanking();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('排行榜'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchRanking(refresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gridWidth = (constraints.maxWidth - 24).clamp(
              0.0,
              double.infinity,
            );

            return _loading
                ? const Center(child: M3ELoadingIndicator())
                : allBooks.isEmpty
                ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.leaderboard_outlined,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无数据',
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
                : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: appBookGridDelegateForWidth(
                    gridWidth,
                    minTileWidth: 156,
                  ),
                  itemCount:
                      displayBooks.length + (hasMore && _loadingMore ? 3 : 0),
                  itemBuilder: (context, index) {
                    if (index >= displayBooks.length) {
                      return const Center(child: M3ELoadingIndicator());
                    }
                    final book = displayBooks[index];
                    return _buildBookCard(context, book, index + 1);
                  },
                );
          },
        ),
      ),
    );
  }

  Widget _buildBookCard(BuildContext context, Book book, int rank) {
    final textTheme = Theme.of(context).textTheme;
    final heroTag = 'ranking_cover_${book.id}';

    return GestureDetector(
      onTap: () {
        AppRouteLauncher.pushDetail(
          context,
          (_) => BookDetailPage(
            bookId: book.id,
            initialCoverUrl: book.cover,
            initialTitle: book.title,
            heroTag: heroTag,
            telemetrySource: TelemetryBookDetailSources.ranking,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Hero(
              tag: heroTag,
              child: BookCoverCard(
                coverUrl: book.cover,
                overlays: [
                  if (rank <= 3)
                    Positioned(
                      left: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              rank == 1
                                  ? const Color(0xFFFFD700) // Gold
                                  : rank == 2
                                  ? const Color(
                                    0xFF78909C,
                                  ) // Silver (blue-tinted)
                                  : const Color(0xFFCD7F32), // Bronze
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$rank',
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (ref
                      .watch(settingsProvider)
                      .isBookTypeBadgeEnabled('ranking'))
                    BookTypeBadge(
                      category: book.category,
                      level: book.level,
                      interiorLevel: book.interiorLevel,
                    ),
                ],
              ),
            ),
          ),
          BookGridTitle(title: book.title),
        ],
      ),
    );
  }
}
