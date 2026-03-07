import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_service.dart';
import 'package:novella/data/services/user_service.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:novella/features/shelf/widgets/shelf_edit_sheets.dart';
import 'package:novella/features/shelf/widgets/shelf_grid_item.dart';

class ShelfFolderPage extends ConsumerStatefulWidget {
  final String folderId;
  final String folderTitle;
  final List<String> folderPath;

  const ShelfFolderPage({
    super.key,
    required this.folderId,
    required this.folderTitle,
    required this.folderPath,
  });

  @override
  ConsumerState<ShelfFolderPage> createState() => _ShelfFolderPageState();
}

class _ShelfFolderPageState extends ConsumerState<ShelfFolderPage> {
  final _logger = Logger('ShelfFolderPage');
  final _userService = UserService();
  final _bookService = BookService();
  final _browseScrollController = ScrollController();
  final _sortScrollController = ScrollController();
  final _gridViewKey = GlobalKey();

  final Map<int, Book> _bookDetails = {};
  final Set<int> _selectedBookIds = {};
  List<ShelfItem> _items = [];
  List<String> _breadcrumbTitles = [];
  bool _isSortDragging = false;
  bool _loading = true;
  bool _isEditMode = false;
  bool _isSortMode = false;
  int? _dragStartIndex;
  int? _dragTargetIndex;
  late String _folderTitle;

  @override
  void initState() {
    super.initState();
    _folderTitle = widget.folderTitle;
    _userService.addListener(_onShelfChanged);
    _loadFolder();
  }

  @override
  void dispose() {
    _userService.removeListener(_onShelfChanged);
    _browseScrollController.dispose();
    _sortScrollController.dispose();
    super.dispose();
  }

  void _onShelfChanged() {
    if (!mounted || _isSortDragging) return;
    _loadFolder();
  }

  Future<void> _loadFolder({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      if (forceRefresh) {
        await _userService.getShelf(forceRefresh: true);
      } else {
        await _userService.ensureInitialized();
      }

      final folder = _userService.getFolderById(widget.folderId);
      final items = _userService.getShelfItemsByParents(widget.folderPath);
      final fetchedBooks = await _fetchMissingBookDetails(items);
      final folderBookIds =
          items
              .where((item) => item.type == ShelfItemType.book)
              .map((item) => item.id as int)
              .toSet();

      if (mounted) {
        setState(() {
          _bookDetails.addAll(fetchedBooks);
          _items = items;
          _folderTitle =
              folder?.title.isNotEmpty == true
                  ? folder!.title
                  : widget.folderTitle;
          _breadcrumbTitles = _userService.getFolderTitles(widget.folderPath);
          _selectedBookIds.removeWhere((id) => !folderBookIds.contains(id));
          _dragStartIndex = null;
          _dragTargetIndex = null;
          _isSortDragging = false;
          _loading = false;
        });
      }

      final scrollController =
          items.isNotEmpty ? _sortScrollController : _browseScrollController;
      if (scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    } catch (e) {
      _logger.severe('Failed to load shelf folder: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('加载文件夹失败'),
          ),
        );
      }
    }
  }

  Future<Map<int, Book>> _fetchMissingBookDetails(List<ShelfItem> items) async {
    final missingIds = <int>{};

    for (final item in items) {
      if (item.type == ShelfItemType.book) {
        final bookId = item.id as int;
        if (!_bookDetails.containsKey(bookId)) {
          missingIds.add(bookId);
        }
        continue;
      }

      for (final previewId in _userService.getDirectChildBookIds(
        item.id as String,
      )) {
        if (!_bookDetails.containsKey(previewId)) {
          missingIds.add(previewId);
        }
      }
    }

    if (missingIds.isEmpty) {
      return const {};
    }

    try {
      final books = await _bookService.getBooksByIds(missingIds.toList());
      return {for (final book in books) book.id: book};
    } catch (e) {
      _logger.warning('Failed to fetch shelf folder books: $e');
      return const {};
    }
  }

  List<int> _folderPreviewBookIds(String folderId) {
    return _userService.getDirectChildBookIds(folderId);
  }

  Map<int, Book> _folderPreviewBookDetails(List<int> previewBookIds) {
    final previewBookDetails = <int, Book>{};
    for (final bookId in previewBookIds) {
      final book = _bookDetails[bookId];
      if (book != null) {
        previewBookDetails[bookId] = book;
      }
    }
    return previewBookDetails;
  }

  String _itemKey(ShelfItem item) {
    return item.type == ShelfItemType.folder
        ? 'folder_${item.id}'
        : 'book_${item.id}';
  }

  List<ShelfItem> _reorderItems(
    List<ShelfItem> items,
    int fromIndex,
    int toIndex,
  ) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= items.length ||
        toIndex >= items.length) {
      return List<ShelfItem>.from(items);
    }

    final reordered = List<ShelfItem>.from(items);
    final item = reordered.removeAt(fromIndex);
    reordered.insert(toIndex, item);
    return reordered;
  }

  Widget _wrapGridItem({
    required ShelfItem item,
    required Widget child,
    required bool showSortHandle,
  }) {
    return KeyedSubtree(key: ValueKey(_itemKey(item)), child: child);
  }

  Widget _buildGridItem(
    BuildContext context,
    ShelfItem item, {
    required bool showSortHandle,
  }) {
    if (item.type == ShelfItemType.folder) {
      final folderId = item.id as String;
      final previewBookIds = _folderPreviewBookIds(folderId);
      final child = ShelfFolderGridItem(
        title: item.title,
        itemCount: _userService.getDirectChildCount(folderId),
        previewBookIds: previewBookIds,
        previewBookDetails: _folderPreviewBookDetails(previewBookIds),
        sortMode: showSortHandle,
        onTap: () => _openFolder(item),
      );

      return _wrapGridItem(
        item: item,
        child: child,
        showSortHandle: showSortHandle,
      );
    }

    final bookId = item.id as int;
    final child = HeroMode(
      enabled: !showSortHandle,
      child: ShelfBookGridItem(
        book: _bookDetails[bookId],
        bookId: bookId,
        heroTag: 'shelf_folder_${widget.folderId}_$bookId',
        selected:
            _isEditMode && !_isSortMode && _selectedBookIds.contains(bookId),
        sortMode: showSortHandle,
        enableHero: !showSortHandle,
        enablePreview: !_isEditMode,
        onTap: () => _openBook(item),
      ),
    );

    return _wrapGridItem(
      item: item,
      child: child,
      showSortHandle: showSortHandle,
    );
  }

  void _handleSortDragStarted(int index) {
    setState(() {
      _isSortDragging = true;
      _dragStartIndex = index;
      _dragTargetIndex = index;
    });
  }

  void _handleSortDragEnd(int index) {
    setState(() {
      _isSortDragging = false;
      _dragTargetIndex = index;
      if (_dragStartIndex == index) {
        _dragStartIndex = null;
        _dragTargetIndex = null;
      }
    });
  }

  Future<void> _handlePageItemsReordered() async {
    final fromIndex = _dragStartIndex;
    final toIndex = _dragTargetIndex;

    setState(() {
      _dragStartIndex = null;
      _dragTargetIndex = null;
      if (fromIndex != null && toIndex != null && fromIndex != toIndex) {
        _items = _reorderItems(_items, fromIndex, toIndex);
      }
    });

    if (fromIndex == null || toIndex == null || fromIndex == toIndex) {
      return;
    }

    await _userService.reorderItemsInParents(
      parents: widget.folderPath,
      fromIndex: fromIndex,
      toIndex: toIndex,
    );
  }

  Future<void> _openFolder(ShelfItem item) async {
    if (_isSortMode) {
      return;
    }

    if (_isEditMode) {
      return;
    }

    final folderId = item.id as String;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ShelfFolderPage(
              folderId: folderId,
              folderTitle: item.title,
              folderPath: [...item.parents, folderId],
            ),
      ),
    );

    if (mounted) {
      await _loadFolder();
    }
  }

  Future<void> _openBook(ShelfItem item) async {
    final bookId = item.id as int;
    final book = _bookDetails[bookId];

    if (_isSortMode) {
      return;
    }

    if (_isEditMode) {
      _toggleBookSelection(bookId);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BookDetailPage(
              bookId: bookId,
              initialCoverUrl: book?.cover,
              initialTitle: book?.title,
              heroTag: 'shelf_folder_${widget.folderId}_$bookId',
            ),
      ),
    );
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _isSortMode = false;
    });
  }

  void _toggleSortMode() {
    if (_selectedBookIds.isNotEmpty) {
      return;
    }

    setState(() {
      _isSortMode = !_isSortMode;
      _dragStartIndex = null;
      _dragTargetIndex = null;
      _isSortDragging = false;
    });
  }

  void _exitEditMode() {
    setState(() {
      _selectedBookIds.clear();
      _dragStartIndex = null;
      _dragTargetIndex = null;
      _isSortDragging = false;
      _isSortMode = false;
      _isEditMode = false;
    });
  }

  void _toggleBookSelection(int bookId) {
    setState(() {
      if (_selectedBookIds.contains(bookId)) {
        _selectedBookIds.remove(bookId);
      } else {
        _selectedBookIds.add(bookId);
      }
    });
  }

  List<ShelfMoveDestination> _moveDestinations() {
    final destinations = <ShelfMoveDestination>[
      const ShelfMoveDestination(
        title: '书架顶层',
        subtitle: '不在任何文件夹中',
        parents: [],
        isRoot: true,
      ),
    ];

    for (final folder in _userService.getFolders(
      excludeFolderId: widget.folderId,
    )) {
      final folderId = folder.id as String;
      final pathTitles = _userService.getFolderTitles(folder.parents);
      destinations.add(
        ShelfMoveDestination(
          title:
              folder.title.isEmpty
                  ? '未命名文件夹'
                  : folder.title,
          subtitle: pathTitles.isEmpty ? null : pathTitles.join(' / '),
          parents: [...folder.parents, folderId],
        ),
      );
    }

    return destinations;
  }

  Future<void> _handleEditConfirm() async {
    if (_selectedBookIds.isEmpty) {
      return;
    }

    final destinations = _moveDestinations();
    final action = await showShelfEditActionSheet(
      context: context,
      selectedBookCount: _selectedBookIds.length,
      selectedFolderCount: 0,
      selectedFolderBookCount: 0,
      canMove: destinations.isNotEmpty,
      moveDisabledReason:
          destinations.isEmpty
              ? '当前没有可移动的目标'
              : null,
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case ShelfEditAction.delete:
        final confirmed = await showShelfDeleteConfirmSheet(
          context: context,
          selectedBookCount: _selectedBookIds.length,
          selectedFolderCount: 0,
          selectedFolderBookCount: 0,
        );
        if (!mounted || !confirmed) {
          return;
        }
        await _removeSelectedBooks();
        break;
      case ShelfEditAction.move:
        final parents = await showShelfMoveDestinationSheet(
          context: context,
          selectedBookCount: _selectedBookIds.length,
          destinations: destinations,
        );
        if (!mounted || parents == null) {
          return;
        }
        await _moveSelectedBooks(parents);
        break;
      case ShelfEditAction.rename:
        break;
    }
  }

  Future<void> _removeSelectedBooks() async {
    final selectedIds = _selectedBookIds.toList(growable: false);
    final success = await _userService.removeBooksFromShelf(selectedIds);
    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已从书架移出 ${selectedIds.length} 本书',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedBookIds.clear();
      _isSortMode = false;
      _isEditMode = false;
    });

    await _loadFolder();
  }

  Future<void> _moveSelectedBooks(List<String> parents) async {
    final selectedIds = _selectedBookIds.toList(growable: false);
    final success = await _userService.moveBooksToParents(selectedIds, parents);
    if (!mounted || !success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已移动 ${selectedIds.length} 本书'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedBookIds.clear();
      _isSortMode = false;
      _isEditMode = false;
    });

    await _loadFolder();
  }

  Widget _buildStandardBody(
    BuildContext context,
    List<ShelfItem> displayItems,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return RefreshIndicator(
      onRefresh: () => _loadFolder(forceRefresh: true),
      child:
          _loading
              ? const Center(child: M3ELoadingIndicator())
              : displayItems.isEmpty
              ? LayoutBuilder(
                builder:
                    (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '当前文件夹为空',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              )
              : CustomScrollView(
                controller: _browseScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (_breadcrumbTitles.length > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Text(
                          _breadcrumbTitles.join(' / '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.58,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildGridItem(
                          context,
                          displayItems[index],
                          showSortHandle: false,
                        );
                      }, childCount: displayItems.length),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom,
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildSortableBody(
    BuildContext context,
    List<ShelfItem> displayItems,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return RefreshIndicator(
      onRefresh: () => _loadFolder(forceRefresh: true),
      child: Column(
        children: [
          if (_breadcrumbTitles.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _breadcrumbTitles.join(' / '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ReorderableBuilder<ShelfItem>.builder(
              itemCount: displayItems.length,
              scrollController: _sortScrollController,
              longPressDelay: const Duration(milliseconds: 180),
              enableDraggable: _isSortMode,
              feedbackScaleFactor: 1,
              dragChildBoxDecoration: const BoxDecoration(),
              onDragStarted: _handleSortDragStarted,
              onDragEnd: _handleSortDragEnd,
              onReorder: (_) {
                unawaited(_handlePageItemsReordered());
              },
              childBuilder: (itemBuilder) {
                return GridView.builder(
                  key: _gridViewKey,
                  controller: _sortScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    12,
                    12,
                    12,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.58,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    return itemBuilder(
                      _buildGridItem(
                        context,
                        displayItems[index],
                        showSortHandle: _isSortMode,
                      ),
                      index,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayItems = _items;
    final appBarTitle =
        _isEditMode
            ? (_isSortMode
                ? '拖拽排序'
                : _selectedBookIds.isEmpty
                ? '编辑文件夹'
                : '已选 ${_selectedBookIds.length} 本')
            : (_folderTitle.isEmpty ? '文件夹' : _folderTitle);

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          if (_isEditMode) ...[
            IconButton(
              icon: Icon(
                Icons.drag_indicator,
                color: _isSortMode ? colorScheme.primary : null,
              ),
              onPressed: _selectedBookIds.isNotEmpty ? null : _toggleSortMode,
              tooltip:
                  _isSortMode
                      ? '退出拖拽排序'
                      : '拖拽排序',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _isSortMode ? null : _exitEditMode,
              tooltip: '取消',
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed:
                  _selectedBookIds.isEmpty || _isSortMode
                      ? null
                      : _handleEditConfirm,
              tooltip: '确认',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _enterEditMode,
              tooltip: '编辑',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _loadFolder(forceRefresh: true),
              tooltip: '刷新',
            ),
          ],
        ],
      ),
      body:
          !_loading && displayItems.isNotEmpty
              ? _buildSortableBody(
                context,
                displayItems,
                colorScheme,
                textTheme,
              )
              : _buildStandardBody(
                context,
                displayItems,
                colorScheme,
                textTheme,
              ),
    );
  }
}
