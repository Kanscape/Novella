import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/widgets/m3e_loading_indicator.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_mark_service.dart';
import 'package:novella/data/services/book_service.dart';
import 'package:novella/data/services/user_service.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:novella/features/settings/settings_provider.dart';
import 'package:novella/features/shelf/shelf_folder_page.dart';
import 'package:novella/features/shelf/widgets/shelf_edit_sheets.dart';
import 'package:novella/features/shelf/widgets/shelf_grid_item.dart';

class ShelfPage extends ConsumerStatefulWidget {
  const ShelfPage({super.key});

  @override
  ConsumerState<ShelfPage> createState() => ShelfPageState();
}

class ShelfPageState extends ConsumerState<ShelfPage> {
  static const int _pageSize = 24;

  final _logger = Logger('ShelfPage');
  final _bookService = BookService();
  final _userService = UserService();
  final _bookMarkService = BookMarkService();
  final _browseScrollController = ScrollController();
  final _sortScrollController = ScrollController();
  final _gridViewKey = GlobalKey();

  final Map<int, Book> _bookDetails = {};
  final Set<int> _selectedBookIds = {};
  final Set<String> _selectedFolderIds = {};
  List<ShelfItem> _rootItems = [];
  List<ShelfItem> _allShelfBookItems = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _isSortDragging = false;
  bool _isEditMode = false;
  bool _isSortMode = false;
  DateTime? _lastRefreshTime;
  int _displayedCount = 0;
  int _selectedFilter = 0;
  int? _dragStartIndex;
  int? _dragTargetIndex;
  Set<int> _markedBookIds = {};

  bool get _hasSelection =>
      _selectedBookIds.isNotEmpty || _selectedFolderIds.isNotEmpty;

  bool get _canRenameSelectedFolder =>
      _selectedBookIds.isEmpty && _selectedFolderIds.length == 1;

  bool get _usesDefaultGrid => _selectedFilter == 0;

  int get _selectedImpactBookCount => _userService.getSelectedBookImpactCount(
    bookIds: _selectedBookIds,
    folderIds: _selectedFolderIds,
  );

  int get _selectedFolderContainedBookCount =>
      _userService.getSelectedBookImpactCount(folderIds: _selectedFolderIds);

  @override
  void initState() {
    super.initState();
    _userService.addListener(_onShelfChanged);
    _browseScrollController.addListener(_onScroll);
    _sortScrollController.addListener(_onScroll);
    _fetchShelf();
  }

  @override
  void dispose() {
    _userService.removeListener(_onShelfChanged);
    _browseScrollController.dispose();
    _sortScrollController.dispose();
    super.dispose();
  }

  void refresh() {
    _refreshGrid(force: true);
  }

  void _onScroll() {
    final controller =
        _usesDefaultGrid ? _sortScrollController : _browseScrollController;

    if (!controller.hasClients || _isSortDragging) {
      return;
    }

    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 200) {
      _loadMoreItems();
    }
  }

  void _onShelfChanged() {
    if (!mounted || _isSortDragging) return;
    _logger.info('Shelf update received, refreshing root shelf...');
    _refreshGrid();
  }

  List<ShelfItem> get _allFilteredItems {
    if (_selectedFilter == 0) {
      return _rootItems;
    }

    return _allShelfBookItems
        .where((item) => _markedBookIds.contains(item.id as int))
        .toList();
  }

  List<ShelfItem> get _displayItems {
    final items = _allFilteredItems;
    final count =
        _displayedCount > items.length ? items.length : _displayedCount;
    return items.take(count).toList();
  }

  Future<void> _fetchShelf({bool force = false}) async {
    if (!force &&
        _lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) <
            const Duration(seconds: 2)) {
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      await _userService.ensureInitialized();
      await _refreshGrid(force: force);
    } catch (e) {
      _logger.severe('Error fetching shelf: $e');
      if (!mounted) return;

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载书架失败')),
      );
    }
  }

  Future<void> _refreshGrid({bool force = false}) async {
    if (force) {
      await _userService.getShelf(forceRefresh: true);
    }

    final hadDisplayedItems = _displayedCount > 0;
    final previousFilteredLength = _allFilteredItems.length;
    final wasShowingAll =
        hadDisplayedItems && _displayedCount >= previousFilteredLength;
    final rootItems = _userService.getShelfItemsByParents(const []);
    final allShelfBookItems = _userService.getAllBookItemsInDisplayOrder();
    final filteredItems =
        _selectedFilter == 0
            ? rootItems
            : allShelfBookItems
                .where((item) => _markedBookIds.contains(item.id as int))
                .toList(growable: false);
    final desiredCount =
        !hadDisplayedItems
            ? _pageSize
            : wasShowingAll
            ? filteredItems.length
            : _displayedCount;
    final nextDisplayedCount =
        desiredCount > filteredItems.length
            ? filteredItems.length
            : desiredCount;
    final visibleBookIds =
        (_selectedFilter == 0 ? rootItems : filteredItems)
            .where((item) => item.type == ShelfItemType.book)
            .map((item) => item.id as int)
            .toSet();
    final visibleFolderIds =
        _selectedFilter == 0
            ? rootItems
                .where((item) => item.type == ShelfItemType.folder)
                .map((item) => item.id as String)
                .toSet()
            : <String>{};

    if (!mounted) {
      return;
    }

    setState(() {
      _rootItems = rootItems;
      _allShelfBookItems = allShelfBookItems;
      _displayedCount = nextDisplayedCount;
      _selectedBookIds.removeWhere(
        (bookId) => !visibleBookIds.contains(bookId),
      );
      _selectedFolderIds.removeWhere(
        (folderId) => !visibleFolderIds.contains(folderId),
      );
      _loading = false;
      _lastRefreshTime = DateTime.now();
    });

    await _ensureBookDetails(_displayItems);
  }

  Future<void> _ensureBookDetails(List<ShelfItem> items) async {
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
      return;
    }

    try {
      final books = await _bookService.getBooksByIds(missingIds.toList());
      if (!mounted) return;

      setState(() {
        for (final book in books) {
          _bookDetails[book.id] = book;
        }
      });
    } catch (e) {
      _logger.warning('Failed to fetch shelf book details: $e');
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
        selected:
            _isEditMode &&
            !_isSortMode &&
            _selectedFolderIds.contains(folderId),
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
        heroTag: 'shelf_cover_$bookId',
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

  Future<void> _refreshMarkedBookIds() async {
    if (_selectedFilter == 0) {
      if (mounted && _markedBookIds.isNotEmpty) {
        setState(() => _markedBookIds = {});
      }
      return;
    }

    final status = BookMarkStatus.values[_selectedFilter];
    final markedIds = await _bookMarkService.getBooksWithStatus(status);
    if (!mounted) return;

    setState(() {
      _markedBookIds = markedIds;
    });
  }

  void _loadMoreItems() {
    final filteredItems = _allFilteredItems;
    if (_loadingMore || _displayedCount >= filteredItems.length) {
      return;
    }

    setState(() => _loadingMore = true);

    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!mounted) return;

      setState(() {
        final nextCount = _displayedCount + _pageSize;
        _displayedCount =
            nextCount > filteredItems.length ? filteredItems.length : nextCount;
        _loadingMore = false;
      });

      await _ensureBookDetails(_displayItems);
    });
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

  Future<void> _handleRootItemsReordered() async {
    final fromIndex = _dragStartIndex;
    final toIndex = _dragTargetIndex;

    setState(() {
      _dragStartIndex = null;
      _dragTargetIndex = null;
      if (fromIndex != null &&
          toIndex != null &&
          fromIndex != toIndex &&
          _selectedFilter == 0) {
        _rootItems = _reorderItems(_rootItems, fromIndex, toIndex);
      }
    });

    if (fromIndex == null ||
        toIndex == null ||
        fromIndex == toIndex ||
        _selectedFilter != 0) {
      return;
    }

    await _userService.reorderItemsInParents(
      parents: const [],
      fromIndex: fromIndex,
      toIndex: toIndex,
    );
  }

  Future<void> _onFilterChanged(int filterIndex) async {
    if (filterIndex == _selectedFilter) return;

    setState(() {
      _selectedFilter = filterIndex;
      _displayedCount = _pageSize;
      _selectedBookIds.clear();
      _selectedFolderIds.clear();
      _dragStartIndex = null;
      _dragTargetIndex = null;
      _isSortDragging = false;
      _isSortMode = false;
      _isEditMode = false;
    });

    await _refreshMarkedBookIds();

    if (!mounted) return;

    final filteredItems = _allFilteredItems;
    setState(() {
      _displayedCount =
          _displayedCount > filteredItems.length
              ? filteredItems.length
              : _displayedCount;
    });

    await _ensureBookDetails(_displayItems);
  }

  Future<void> _openFolder(ShelfItem item) async {
    if (_isSortMode) {
      return;
    }

    if (_isEditMode) {
      _toggleFolderSelection(item.id as String);
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

    if (_selectedFilter > 0) {
      await _refreshMarkedBookIds();
    }
    await _refreshGrid();
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
              heroTag: 'shelf_cover_$bookId',
            ),
      ),
    );

    await _refreshGrid();
    if (_selectedFilter > 0) {
      await _refreshMarkedBookIds();
    }
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _isSortMode = false;
    });
  }

  void _toggleSortMode() {
    if (_hasSelection || _selectedFilter != 0) {
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
      _selectedFolderIds.clear();
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

  void _toggleFolderSelection(String folderId) {
    setState(() {
      if (_selectedFolderIds.contains(folderId)) {
        _selectedFolderIds.remove(folderId);
      } else {
        _selectedFolderIds.add(folderId);
      }
    });
  }

  List<ShelfMoveDestination> _moveDestinations() {
    final folders = _userService.getFolders();

    return folders
        .map((folder) {
          final folderId = folder.id as String;
          final pathTitles = _userService.getFolderTitles(folder.parents);
          return ShelfMoveDestination(
            title:
                folder.title.isEmpty
                    ? '未命名文件夹'
                    : folder.title,
            subtitle: pathTitles.isEmpty ? null : pathTitles.join(' / '),
            parents: [...folder.parents, folderId],
          );
        })
        .toList(growable: false);
  }

  Future<void> _handleEditConfirm() async {
    if (!_hasSelection) {
      return;
    }

    final destinations = _moveDestinations();
    final hasSelectedFolders = _selectedFolderIds.isNotEmpty;
    final action = await showShelfEditActionSheet(
      context: context,
      selectedBookCount: _selectedBookIds.length,
      selectedFolderCount: _selectedFolderIds.length,
      selectedFolderBookCount: _selectedFolderContainedBookCount,
      canMove:
          !hasSelectedFolders &&
          _selectedBookIds.isNotEmpty &&
          destinations.isNotEmpty,
      showRenameOption: _selectedFilter == 0,
      canRename: _canRenameSelectedFolder,
      moveDisabledReason:
          hasSelectedFolders
              ? '选中文件夹时暂不支持移动'
              : destinations.isEmpty
              ? '当前没有可移动的目标'
              : null,
      renameDisabledReason:
          '仅支持单选文件夹重命名',
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case ShelfEditAction.delete:
        final confirmed = await showShelfDeleteConfirmSheet(
          context: context,
          selectedBookCount: _selectedBookIds.length,
          selectedFolderCount: _selectedFolderIds.length,
          selectedFolderBookCount: _selectedFolderContainedBookCount,
        );
        if (!mounted || !confirmed) {
          return;
        }
        await _deleteSelectedItems();
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
        await _renameSelectedFolder();
        break;
    }
  }

  Future<void> _deleteSelectedItems() async {
    final selectedBookIds = _selectedBookIds.toList(growable: false);
    final selectedFolderIds = _selectedFolderIds.toList(growable: false);
    final impactedBookCount = _selectedImpactBookCount;
    final folderCount = selectedFolderIds.length;
    final success = await _userService.removeSelectionFromShelf(
      bookIds: selectedBookIds,
      folderIds: selectedFolderIds,
    );
    if (!mounted || !success) {
      return;
    }

    final snackBarText =
        folderCount > 0
            ? impactedBookCount > 0
                ? '已删除 $impactedBookCount 本书和 $folderCount 个文件夹'
                : '已删除 $folderCount 个文件夹'
            : '已从书架移出 ${selectedBookIds.length} 本书';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackBarText),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedBookIds.clear();
      _selectedFolderIds.clear();
      _isSortMode = false;
      _isEditMode = false;
    });

    await _refreshMarkedBookIds();
    await _refreshGrid();
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
      _selectedFolderIds.clear();
      _isSortMode = false;
      _isEditMode = false;
    });

    await _refreshMarkedBookIds();
    await _refreshGrid();
  }

  Future<void> _renameSelectedFolder() async {
    if (!_canRenameSelectedFolder) {
      return;
    }

    final folderId = _selectedFolderIds.first;
    final folder = _userService.getFolderById(folderId);
    if (folder == null) {
      return;
    }

    final currentTitle = folder.title.trim();
    final nextName = await showShelfRenameFolderSheet(
      context: context,
      initialName: folder.title,
    );
    if (!mounted || nextName == null) {
      return;
    }

    final trimmedName = nextName.trim();
    if (trimmedName.isEmpty || trimmedName == currentTitle) {
      return;
    }

    final success = await _userService.renameFolder(folderId, trimmedName);
    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '文件夹名称无效或已存在',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已重命名文件夹：$trimmedName',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _selectedBookIds.clear();
      _selectedFolderIds.clear();
      _isSortMode = false;
      _isEditMode = false;
    });

    await _refreshGrid();
  }

  Future<void> _createFolder() async {
    if (_hasSelection || _isSortMode) {
      return;
    }

    final folderName = await showShelfCreateFolderSheet(context: context);
    if (!mounted || folderName == null) {
      return;
    }

    final folderId = await _userService.createFolder(folderName);
    if (!mounted) {
      return;
    }

    if (folderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '文件夹名称无效或已存在',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已新建文件夹：$folderName'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _refreshGrid();
  }

  IconData _getFilterIcon(int filterIndex) {
    switch (filterIndex) {
      case 1:
        return Icons.schedule;
      case 2:
        return Icons.auto_stories;
      case 3:
        return Icons.check_circle_outline;
      default:
        return Icons.folder_open_outlined;
    }
  }

  String _getFilterLabel(int filterIndex) {
    switch (filterIndex) {
      case 1:
        return '待读';
      case 2:
        return '在读';
      case 3:
        return '已读';
      default:
        return '';
    }
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final selectedImpactCount = _selectedImpactBookCount;
    final title =
        _isEditMode
            ? (_isSortMode
                ? '拖拽排序'
                : !_hasSelection
                ? '编辑书架'
                : '已选 $selectedImpactCount 本')
            : '书架';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (_isEditMode) ...[
            if (_selectedFilter == 0)
              IconButton(
                icon: const Icon(Icons.add),
                onPressed:
                    (_hasSelection || _isSortMode) ? null : _createFolder,
                tooltip: '新建文件夹',
              ),
            if (_selectedFilter == 0)
              IconButton(
                icon: Icon(
                  Icons.drag_indicator,
                  color: _isSortMode ? colorScheme.primary : null,
                ),
                onPressed: _hasSelection ? null : _toggleSortMode,
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
                  _hasSelection && !_isSortMode ? _handleEditConfirm : null,
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
              onPressed: () => _fetchShelf(force: true),
              tooltip: '刷新',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterTabs(ColorScheme colorScheme) {
    const labels = [
      '默认',
      '待读',
      '在读',
      '已读',
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _selectedFilter == index;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _onFilterChanged(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _selectedFilter == 0
                ? Icons.folder_open_outlined
                : _getFilterIcon(_selectedFilter),
            size: 64,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          if (_selectedFilter == 0)
            Text(
              '书架空空如也',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Text(
              '没有标记为${_getFilterLabel(_selectedFilter)}的书籍',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '长按详情页书签按钮即可标记',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStandardGrid({
    required List<ShelfItem> displayItems,
    required bool hasMore,
    required AppSettings settings,
  }) {
    return RefreshIndicator(
      onRefresh: () => _fetchShelf(force: true),
      child: GridView.builder(
        controller: _browseScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          12,
          12,
          12,
          settings.useIOS26Style ? 86 : 24,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 10,
          mainAxisSpacing: 12,
        ),
        itemCount: displayItems.length + (hasMore && _loadingMore ? 3 : 0),
        itemBuilder: (context, index) {
          if (index >= displayItems.length) {
            return const Center(child: M3ELoadingIndicator());
          }

          return _buildGridItem(
            context,
            displayItems[index],
            showSortHandle: false,
          );
        },
      ),
    );
  }

  Widget _buildEditableGrid({
    required List<ShelfItem> displayItems,
    required bool hasMore,
    required AppSettings settings,
  }) {
    return RefreshIndicator(
      onRefresh: () => _fetchShelf(force: true),
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
          unawaited(_handleRootItemsReordered());
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
              settings.useIOS26Style ? 86 : 24,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.58,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: displayItems.length + (hasMore && _loadingMore ? 3 : 0),
            itemBuilder: (context, index) {
              if (index >= displayItems.length) {
                return const Center(child: M3ELoadingIndicator());
              }

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
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, colorScheme, textTheme),
            _buildFilterTabs(colorScheme),
            Expanded(
              child: Builder(
                builder: (context) {
                  final allFilteredItems = _allFilteredItems;
                  final displayItems = _displayItems;
                  final hasMore = _displayedCount < allFilteredItems.length;

                  if (_loading) {
                    return const Center(child: M3ELoadingIndicator());
                  }

                  if (allFilteredItems.isEmpty) {
                    return _buildEmptyState(colorScheme, textTheme);
                  }

                  return _usesDefaultGrid
                      ? _buildEditableGrid(
                        displayItems: displayItems,
                        hasMore: hasMore,
                        settings: settings,
                      )
                      : _buildStandardGrid(
                        displayItems: displayItems,
                        hasMore: hasMore,
                        settings: settings,
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
