import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/layout/app_window_class.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_content_filter.dart';
import 'package:novella/data/services/book_search_mode.dart';
import 'package:novella/data/services/book_service.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/telemetry/telemetry_events.dart';
import 'package:novella/core/telemetry/telemetry_service.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novella/features/settings/settings_page.dart';
import 'package:novella/src/widgets/book_cover_card.dart';
import 'package:novella/src/widgets/book_grid_title.dart';
import 'package:novella/src/widgets/book_type_badge.dart';

class SearchPage extends ConsumerStatefulWidget {
  final String? initialKeyword;
  final bool initialExact;
  final BookSearchMode initialMode;

  const SearchPage({
    super.key,
    this.initialKeyword,
    this.initialExact = false,
    BookSearchMode? initialMode,
  }) : initialMode =
           initialMode ??
           (initialExact ? BookSearchMode.exact : BookSearchMode.fuzzy);

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchModeOption {
  const _SearchModeOption({
    required this.mode,
    required this.label,
    required this.icon,
  });

  final BookSearchMode mode;
  final String label;
  final IconData icon;
}

const _searchModeOptions = <_SearchModeOption>[
  _SearchModeOption(
    mode: BookSearchMode.exact,
    label: '精确搜索',
    icon: Icons.format_quote_rounded,
  ),
  _SearchModeOption(
    mode: BookSearchMode.title,
    label: '按书名',
    icon: Icons.title,
  ),
  _SearchModeOption(
    mode: BookSearchMode.author,
    label: '按作者',
    icon: Icons.person_outline,
  ),
  _SearchModeOption(
    mode: BookSearchMode.name,
    label: '按系列名',
    icon: Icons.collections_bookmark_outlined,
  ),
  _SearchModeOption(
    mode: BookSearchMode.tags,
    label: '按标签',
    icon: Icons.sell_outlined,
  ),
];

class _SearchPageState extends ConsumerState<SearchPage> {
  final _logger = Logger('SearchPage');
  final _bookService = BookService();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  Animation<double>? _initialFocusRouteAnimation;
  AnimationStatusListener? _initialFocusStatusListener;

  // 状态
  List<String> _history = [];
  final List<Book> _allValidBooks = [];
  int _currentFrontendPage = 1;
  int _nextBackendPage = 1;
  bool _hasReachedEnd = false;
  bool _loading = false;
  bool _hasSearched = false;
  String? _pendingDeleteItem;
  String _lastKeyword = '';
  BookSearchMode _lastSearchMode = BookSearchMode.fuzzy;
  bool _searchOptionsExpanded = false;
  static const int _pageSize = 24;

  @override
  void initState() {
    super.initState();
    TelemetryService.instance.trackScreenView(
      TelemetryScreens.search,
      screenClass: 'SearchPage',
      properties: {
        TelemetryProperties.seriesSearchMode: widget.initialMode.name,
      },
    );
    _initializeSearchPage();
  }

  Future<void> _initializeSearchPage() async {
    final initialKeyword = widget.initialKeyword?.trim() ?? '';
    if (initialKeyword.isNotEmpty) {
      _searchController.text = initialKeyword;
    }

    await _loadHistory();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (initialKeyword.isNotEmpty) {
        _submitSearch(
          overrideKeyword: initialKeyword,
          mode: widget.initialMode,
        );
      } else {
        _requestInitialFocusAfterRouteTransition();
      }
    });
  }

  @override
  void dispose() {
    final initialFocusStatusListener = _initialFocusStatusListener;
    if (initialFocusStatusListener != null) {
      _initialFocusRouteAnimation?.removeStatusListener(
        initialFocusStatusListener,
      );
    }
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _requestInitialFocusAfterRouteTransition() {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null ||
        routeAnimation.status == AnimationStatus.completed) {
      _focusNode.requestFocus();
      return;
    }

    late final AnimationStatusListener statusListener;
    statusListener = (status) {
      if (status != AnimationStatus.completed) return;
      routeAnimation.removeStatusListener(statusListener);
      if (_initialFocusStatusListener == statusListener) {
        _initialFocusRouteAnimation = null;
        _initialFocusStatusListener = null;
      }
      if (mounted) {
        _focusNode.requestFocus();
      }
    };

    _initialFocusRouteAnimation = routeAnimation;
    _initialFocusStatusListener = statusListener;
    routeAnimation.addStatusListener(statusListener);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('search_history') ?? [];
    if (!mounted) return;
    setState(() {
      _history = history;
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', _history);
  }

  void _addToHistory(String keyword) {
    if (keyword.isEmpty) return;
    setState(() {
      // 若存在则移除，然后添加到头部
      _history.remove(keyword);
      _history.insert(0, keyword);
      // 保留最多20条记录
      if (_history.length > 20) {
        _history = _history.sublist(0, 20);
      }
    });
    _saveHistory();
  }

  void _removeFromHistory(String keyword) {
    setState(() {
      _history.remove(keyword);
      _pendingDeleteItem = null;
    });
    _saveHistory();
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('清空搜索历史'),
            content: const Text('确定要清空所有搜索记录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('清空'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _history.clear();
      });
      _saveHistory();
    }
  }

  void _submitSearch({
    String? overrideKeyword,
    BookSearchMode mode = BookSearchMode.fuzzy,
  }) {
    final keyword = overrideKeyword ?? _searchController.text.trim();
    if (keyword.isEmpty) return;
    final effectiveMode =
        mode == BookSearchMode.fuzzy && isQuotedBookSearchKeyword(keyword)
            ? BookSearchMode.exact
            : mode;

    // 收起键盘
    FocusScope.of(context).unfocus();

    _addToHistory(keyword);
    _lastKeyword = keyword;
    _lastSearchMode = effectiveMode;
    if (_searchController.text != keyword) {
      _searchController.text = keyword;
    }

    _allValidBooks.clear();
    _nextBackendPage = 1;
    _hasReachedEnd = false;

    _fetchPage(1);
  }

  Future<void> _fetchPage(int page) async {
    if (_lastKeyword.isEmpty) return;

    setState(() {
      _loading = true;
      _hasSearched = true;
    });

    try {
      final settings = ref.read(settingsProvider);
      int targetValidCount = page * _pageSize;

      while (_allValidBooks.length < targetValidCount && !_hasReachedEnd) {
        final result = await _bookService.searchBooks(
          _lastKeyword,
          mode: _lastSearchMode,
          page: _nextBackendPage,
          size: _pageSize,
          ignoreJapanese: settings.ignoreJapanese,
          ignoreAI: settings.ignoreAI,
        );

        final validBooks = filterBooksByContentSettings(
          result.books,
          ignoreJapanese: settings.ignoreJapanese,
          ignoreAI: settings.ignoreAI,
          ignoreLevel6: settings.ignoreLevel6,
        );

        _allValidBooks.addAll(validBooks);

        if (_nextBackendPage >= result.totalPages || result.books.isEmpty) {
          _hasReachedEnd = true;
          break;
        } else {
          _nextBackendPage++;
        }
      }

      if (mounted) {
        setState(() {
          _currentFrontendPage = page;
          _loading = false;
        });

        // 翻页时回到顶部
        if (_scrollController.hasClients && page != 1) {
          _scrollController.jumpTo(0);
        }
      }
    } catch (e) {
      _logger.severe('Search failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('搜索失败')));
      }
    }
  }

  bool get _canGoNext {
    if (!_hasReachedEnd) return true;
    int maxPages = (_allValidBooks.length / _pageSize).ceil();
    return _currentFrontendPage < maxPages;
  }

  bool get _shouldShowPagination {
    return _allValidBooks.length > _pageSize || !_hasReachedEnd;
  }

  Widget _buildPagination() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton.tonalIcon(
            onPressed:
                _currentFrontendPage > 1 && !_loading
                    ? () => _fetchPage(_currentFrontendPage - 1)
                    : null,
            icon: const Icon(Icons.navigate_before),
            label: const Text('上一页'),
          ),
          const SizedBox(width: 16),
          Text(
            '第 $_currentFrontendPage 页',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.tonalIcon(
            onPressed:
                _canGoNext && !_loading
                    ? () => _fetchPage(_currentFrontendPage + 1)
                    : null,
            icon: const Icon(Icons.navigate_next),
            label: const Text('下一页'),
          ),
        ],
      ),
    );
  }

  void _onHistoryTap(String keyword) {
    // 先取消待删除状态
    if (_pendingDeleteItem != null && _pendingDeleteItem != keyword) {
      setState(() {
        _pendingDeleteItem = null;
      });
      return;
    }
    // 搜索前收起键盘
    FocusScope.of(context).unfocus();
    _submitSearch(overrideKeyword: keyword);
  }

  void _onHistoryLongPress(String keyword) {
    setState(() {
      _pendingDeleteItem = keyword;
    });
  }

  void _selectSearchMode(BookSearchMode mode) {
    final keyword = _searchController.text.trim();
    final nextMode = _lastSearchMode == mode ? BookSearchMode.fuzzy : mode;
    if (keyword.isEmpty) {
      if (_lastSearchMode == mode) {
        setState(() {
          _lastSearchMode = BookSearchMode.fuzzy;
          _searchOptionsExpanded = false;
        });
      }
      _focusNode.requestFocus();
      return;
    }
    setState(() {
      _searchOptionsExpanded = false;
    });
    _submitSearch(overrideKeyword: keyword, mode: nextMode);
  }

  String get _emptySearchText {
    return switch (_lastSearchMode) {
      BookSearchMode.exact => '没有找到精确搜索结果',
      BookSearchMode.title => '没有找到书名搜索结果',
      BookSearchMode.author => '没有找到作者搜索结果',
      BookSearchMode.name => '没有找到系列名搜索结果',
      BookSearchMode.tags => '没有找到标签搜索结果',
      BookSearchMode.fuzzy => '没有找到相关书籍',
    };
  }

  Widget _buildSearchContent(ColorScheme colorScheme, TextTheme textTheme) {
    if (_loading) {
      return const Center(child: M3ELoadingIndicator());
    }
    if (_hasSearched) {
      return _buildSearchResults(colorScheme, textTheme);
    }
    return _buildHistorySection(colorScheme, textTheme);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: [
          IconButton(
            tooltip: _searchOptionsExpanded ? '收起搜索方式' : '搜索方式',
            icon: Icon(_searchOptionsExpanded ? Icons.expand_less : Icons.tune),
            onPressed:
                () => setState(() {
                  _searchOptionsExpanded = !_searchOptionsExpanded;
                }),
          ),
          IconButton(
            tooltip: '搜索',
            icon: const Icon(Icons.search),
            onPressed: () => _submitSearch(mode: _lastSearchMode),
          ),
        ],
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: '搜索书籍...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onChanged: (_) {
            if (_searchOptionsExpanded) {
              setState(() {});
            }
          },
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _submitSearch(mode: _lastSearchMode),
        ),
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child:
                _searchOptionsExpanded
                    ? _buildSearchModePanel(colorScheme, textTheme)
                    : const SizedBox(
                      key: ValueKey('search_mode_panel_empty'),
                      width: double.infinity,
                    ),
          ),
          Expanded(child: _buildSearchContent(colorScheme, textTheme)),
        ],
      ),
    );
  }

  Widget _buildSearchModePanel(ColorScheme colorScheme, TextTheme textTheme) {
    return ColoredBox(
      key: const ValueKey('search_mode_panel'),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Material(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.86),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  _searchModeOptions
                      .map(
                        (option) =>
                            _buildSearchModeRow(option, colorScheme, textTheme),
                      )
                      .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchModeRow(
    _SearchModeOption option,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final selected = _lastSearchMode == option.mode;
    final enabled = _searchController.text.trim().isNotEmpty;
    final foreground =
        !enabled
            ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
            : selected
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Material(
        color:
            enabled && selected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => _selectSearchMode(option.mode) : null,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(option.icon, size: 22, color: foreground),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_rounded, size: 22, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection(ColorScheme colorScheme, TextTheme textTheme) {
    return GestureDetector(
      onTap: () {
        // 点击空白区域取消待删除状态
        if (_pendingDeleteItem != null) {
          setState(() {
            _pendingDeleteItem = null;
          });
        }
      },
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '搜索历史',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_history.isNotEmpty)
                  TextButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 历史记录标签
            if (_history.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    '暂无搜索记录',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _history.map((keyword) {
                      final isPendingDelete = _pendingDeleteItem == keyword;
                      return GestureDetector(
                        onTap: () {
                          if (isPendingDelete) {
                            _removeFromHistory(keyword);
                          } else {
                            _onHistoryTap(keyword);
                          }
                        },
                        onLongPress: () => _onHistoryLongPress(keyword),
                        child: Chip(
                          label: Text(
                            isPendingDelete ? '删除?' : keyword,
                            style: TextStyle(
                              color:
                                  isPendingDelete
                                      ? colorScheme.error
                                      : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          backgroundColor:
                              isPendingDelete
                                  ? colorScheme.errorContainer
                                  : colorScheme.surfaceContainerHighest,
                          side: BorderSide.none,
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(ColorScheme colorScheme, TextTheme textTheme) {
    if (_allValidBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              _emptySearchText,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final startIndex = (_currentFrontendPage - 1) * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, _allValidBooks.length);
    final displayBooks =
        startIndex < _allValidBooks.length
            ? _allValidBooks.sublist(startIndex, endIndex)
            : <Book>[];

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              return SliverGrid(
                gridDelegate: appBookGridDelegateForWidth(
                  constraints.crossAxisExtent,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _buildBookCard(context, displayBooks[index]);
                }, childCount: displayBooks.length),
              );
            },
          ),
        ),
        if (_shouldShowPagination)
          SliverToBoxAdapter(child: _buildPagination()),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ),
      ],
    );
  }

  Widget _buildBookCard(BuildContext context, Book book) {
    final heroTag = 'search_cover_${book.id}';

    return GestureDetector(
      onTap: () {
        AppRouteLauncher.pushDetail(
          context,
          (_) => BookDetailPage(
            bookId: book.id,
            initialCoverUrl: book.cover,
            initialTitle: book.title,
            heroTag: heroTag,
            telemetrySource: TelemetryBookDetailSources.search,
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
                  if (ref
                      .watch(settingsProvider)
                      .isBookTypeBadgeEnabled('search'))
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
