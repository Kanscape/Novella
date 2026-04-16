import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/layout/app_window_class.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/core/navigation/app_route_launcher.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_cover_hint_service.dart';
import 'package:novella/data/services/reading_progress_service.dart';
import 'package:novella/data/services/user_service.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:novella/features/settings/settings_page.dart';
import 'package:novella/features/shelf/shelf_book_detail_queue.dart';
import 'package:novella/features/shelf/widgets/shelf_grid_item.dart';
import 'package:visibility_detector/visibility_detector.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => HistoryPageState();
}

class HistoryPageState extends ConsumerState<HistoryPage> {
  static const int _prefetchBehindCount = 3;
  static const int _prefetchAheadCount = 9;

  final _logger = Logger('HistoryPage');
  final _userService = UserService();
  final _bookCoverHintService = BookCoverHintService();
  final _progressService = ReadingProgressService();
  final _scrollController = ScrollController();
  late final ShelfBookDetailQueue _detailQueue;

  final Map<int, Book> _bookDetails = <int, Book>{};
  final Map<int, ReadPosition> _localReadPositions = <int, ReadPosition>{};
  final Set<String> _visibleItemKeys = <String>{};
  final Set<int> _pendingInitialDetailIds = <int>{};
  final Set<String> _revealedBookCoverKeys = <String>{};
  List<int> _bookIds = <int>[];
  bool _loading = true;
  bool _refreshing = false;
  bool _waitingForVisibleDetails = false;
  String? _error;
  Timer? _visibleDetailsFallbackTimer;
  int _refreshEpoch = 0;
  bool _isTabActive = true;

  @override
  void initState() {
    super.initState();
    unawaited(_bookCoverHintService.ensureInitialized());
    _detailQueue = ShelfBookDetailQueue(
      hasBook: (id) => _bookDetails.containsKey(id),
      onBooksLoaded: _handleBooksLoaded,
      onError: (error) {
        _logger.warning('Failed to fetch history book details: $error');
        _releaseVisibleDetailsGate();
      },
      requestScope: RequestScopes.history,
      priority: RequestPriority.high,
    );
    _fetchHistory();
  }

  @override
  void dispose() {
    _detailQueue.dispose();
    _visibleDetailsFallbackTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void refresh() {
    _fetchHistory(force: true, silentIfPossible: true);
  }

  void setTabActive(bool active) {
    if (_isTabActive == active) {
      return;
    }

    _isTabActive = active;
    _refreshEpoch++;

    if (!active) {
      _detailQueue.cancelPending();
      _visibleItemKeys.clear();
      _pendingInitialDetailIds.clear();
      _releaseVisibleDetailsGate();
      return;
    }

    if (_loading || _waitingForVisibleDetails) {
      unawaited(_fetchHistory(silentIfPossible: true));
    }
  }

  void _beginVisibleDetailsGate() {
    _visibleDetailsFallbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _waitingForVisibleDetails = true;
      });
    }
    _visibleDetailsFallbackTimer = Timer(const Duration(milliseconds: 900), () {
      _releaseVisibleDetailsGate();
    });
  }

  void _releaseVisibleDetailsGate() {
    _visibleDetailsFallbackTimer?.cancel();
    if (!mounted || !_waitingForVisibleDetails) {
      return;
    }

    setState(() {
      _waitingForVisibleDetails = false;
    });
    _pendingInitialDetailIds.clear();
  }

  void _handleBooksLoaded(List<Book> books) {
    if (!mounted || !_isTabActive) {
      return;
    }

    final activeBookIds = _bookIds.toSet();
    var shouldReleaseGate = false;
    setState(() {
      for (final book in books) {
        if (!activeBookIds.contains(book.id)) {
          continue;
        }
        _bookDetails[book.id] = book;
        _pendingInitialDetailIds.remove(book.id);
      }
      if (_waitingForVisibleDetails && _pendingInitialDetailIds.isEmpty) {
        _waitingForVisibleDetails = false;
        shouldReleaseGate = true;
      }
    });
    if (shouldReleaseGate) {
      _visibleDetailsFallbackTimer?.cancel();
    }
  }

  Set<int> _collectInitialDetailIds(List<int> bookIds) {
    final detailIds = <int>{};
    for (final bookId in bookIds.take(12)) {
      if (!_bookDetails.containsKey(bookId)) {
        detailIds.add(bookId);
      }
    }
    return detailIds;
  }

  void _trackVisibleItem(List<int> bookIds, int index) {
    final bookId = bookIds[index];
    final itemKey = 'history_book_$bookId';
    if (!_visibleItemKeys.add(itemKey)) {
      return;
    }

    final startIndex = (index - _prefetchBehindCount).clamp(0, bookIds.length);
    final endIndex = (index + _prefetchAheadCount + 1).clamp(0, bookIds.length);
    _detailQueue.enqueue(bookIds.sublist(startIndex, endIndex));
  }

  void _rememberBookCoverReveal(int bookId) {
    _revealedBookCoverKeys.add('history_book_$bookId');
  }

  String? _bookTitleHint(int bookId) {
    final localTitle = _localReadPositions[bookId]?.title;
    if (localTitle?.isNotEmpty == true) {
      return localTitle;
    }
    return _bookCoverHintService.getTitle(bookId);
  }

  String? _bookCoverHint(int bookId) {
    final localCover = _localReadPositions[bookId]?.cover;
    if (localCover?.isNotEmpty == true) {
      return localCover;
    }
    return _bookCoverHintService.getCoverUrl(bookId);
  }

  Future<Map<int, ReadPosition>> _loadLocalReadPositions(
    List<int> bookIds,
  ) async {
    final entries = await Future.wait(
      bookIds.map((bookId) async {
        final position = await _progressService.getLocalPosition(bookId);
        return MapEntry(bookId, position);
      }),
    );

    return <int, ReadPosition>{
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  Future<void> _fetchHistory({
    bool force = false,
    bool silentIfPossible = false,
  }) async {
    if (_refreshing) {
      return;
    }

    final requestEpoch = ++_refreshEpoch;
    final canSilentRefresh =
        silentIfPossible && (_bookIds.isNotEmpty || _bookDetails.isNotEmpty);

    if (mounted && !canSilentRefresh) {
      setState(() {
        _loading = true;
        _refreshing = force;
        _error = null;
      });
    } else if (mounted) {
      setState(() {
        _refreshing = true;
      });
    }

    try {
      final bookIds = await _userService.getReadHistory();
      if (!mounted || !_isTabActive || requestEpoch != _refreshEpoch) {
        return;
      }

      final localReadPositions = await _loadLocalReadPositions(bookIds);
      if (!mounted || !_isTabActive || requestEpoch != _refreshEpoch) {
        return;
      }

      final activeBookIds = bookIds.toSet();
      final initialDetailIds = _collectInitialDetailIds(bookIds);
      final needsVisibleDetails = initialDetailIds.isNotEmpty;
      final shouldBlockForDetails = !canSilentRefresh && needsVisibleDetails;

      _detailQueue.resetRetriableState();
      _visibleItemKeys.clear();
      _pendingInitialDetailIds
        ..clear()
        ..addAll(initialDetailIds);
      _localReadPositions
        ..clear()
        ..addAll(localReadPositions);
      _bookDetails.removeWhere((bookId, _) => !activeBookIds.contains(bookId));

      if (!mounted || !_isTabActive || requestEpoch != _refreshEpoch) {
        return;
      }

      setState(() {
        _bookIds = bookIds;
        _loading = false;
        _refreshing = false;
        _error = null;
        _waitingForVisibleDetails = shouldBlockForDetails;
      });

      if (bookIds.isEmpty) {
        _releaseVisibleDetailsGate();
        return;
      }

      if (needsVisibleDetails) {
        _detailQueue.enqueue(initialDetailIds);
        if (shouldBlockForDetails) {
          _beginVisibleDetailsGate();
        } else {
          _releaseVisibleDetailsGate();
        }
      } else {
        _releaseVisibleDetailsGate();
      }
    } catch (e) {
      _logger.severe('Failed to fetch history: $e');
      if (!mounted || !_isTabActive || requestEpoch != _refreshEpoch) {
        return;
      }

      if (canSilentRefresh) {
        setState(() {
          _refreshing = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isDismissible: false,
      builder: (sheetContext) {
        final colorScheme = Theme.of(sheetContext).colorScheme;
        final textTheme = Theme.of(sheetContext).textTheme;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Text(
                  '清空历史记录',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '确定要清空所有阅读历史吗？此操作不可恢复。',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(Icons.delete, color: colorScheme.error),
                title: Text(
                  '确认清空',
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => Navigator.pop(sheetContext, true),
              ),
              ListTile(
                leading: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                title: const Text('取消'),
                onTap: () => Navigator.pop(sheetContext, false),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await _userService.clearReadHistory();
    if (!mounted || !success) {
      return;
    }

    _detailQueue.resetRetriableState();
    _visibleItemKeys.clear();
    _pendingInitialDetailIds.clear();
    _localReadPositions.clear();
    _bookDetails.clear();
    _releaseVisibleDetailsGate();

    setState(() {
      _bookIds = <int>[];
      _error = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清空历史记录')));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, colorScheme, textTheme),
            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    () => _fetchHistory(force: true, silentIfPossible: true),
                child: _buildContent(context, colorScheme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '历史',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              if (_bookIds.isNotEmpty)
                IconButton(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '清空历史',
                ),
              IconButton(
                onPressed:
                    () => _fetchHistory(force: true, silentIfPossible: true),
                icon: const Icon(Icons.refresh),
                tooltip: '刷新',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ColorScheme colorScheme) {
    final settings = ref.watch(settingsProvider);

    if (_loading) {
      return const Center(child: M3ELoadingIndicator());
    }

    if (_waitingForVisibleDetails) {
      return const Center(child: M3ELoadingIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text('加载失败', style: TextStyle(color: colorScheme.error)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _fetchHistory(force: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_bookIds.isEmpty) {
      return LayoutBuilder(
        builder:
            (context, constraints) => SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: colorScheme.onSurfaceVariant.withAlpha(100),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '暂无阅读记录',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );
    }

    final bookIds = _bookIds;
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            appBottomContentPadding(
              context,
              useIOS26Style: settings.useIOS26Style,
            ),
          ),
          gridDelegate: appBookGridDelegateForWidth(constraints.maxWidth - 24),
          itemCount: bookIds.length,
          itemBuilder: (context, index) {
            final bookId = bookIds[index];
            return VisibilityDetector(
              key: ValueKey('history_visibility_$bookId'),
              onVisibilityChanged: (info) {
                if (info.visibleFraction > 0) {
                  _trackVisibleItem(bookIds, index);
                }
              },
              child: _buildBookItem(bookId),
            );
          },
        );
      },
    );
  }

  Widget _buildBookItem(int bookId) {
    final book = _bookDetails[bookId];
    final coverUrlHint = book == null ? _bookCoverHint(bookId) : null;
    final titleHint = book == null ? _bookTitleHint(bookId) : null;
    final heroTag = 'history_cover_$bookId';

    return ShelfBookGridItem(
      book: book,
      coverUrlHint: coverUrlHint,
      titleHint: titleHint,
      bookId: bookId,
      heroTag: heroTag,
      badgeContext: 'history',
      resolveHintCoverImage: true,
      coverRevealed: _revealedBookCoverKeys.contains('history_book_$bookId'),
      onCoverRevealed: () => _rememberBookCoverReveal(bookId),
      onTap: () {
        AppRouteLauncher.pushDetail(
          context,
          (_) => BookDetailPage(
            bookId: bookId,
            initialCoverUrl: book?.cover ?? coverUrlHint,
            initialTitle: book?.title ?? titleHint,
            heroTag: heroTag,
          ),
        ).then((_) {
          if (mounted) {
            _fetchHistory(force: true, silentIfPossible: true);
          }
        });
      },
    );
  }
}
