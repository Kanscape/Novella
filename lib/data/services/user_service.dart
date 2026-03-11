import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:novella/core/network/request_queue.dart';
import 'package:novella/core/network/signalr_service.dart';
import 'package:novella/data/models/book.dart';
import 'package:uuid/uuid.dart';

class UserService extends ChangeNotifier {
  static final Logger _logger = Logger('UserService');

  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final SignalRService _signalRService = SignalRService();
  final Uuid _uuid = const Uuid();

  List<Map<String, dynamic>> _shelfCache = [];
  bool _initialized = false;
  Future<void> _pendingShelfSync = Future.value();

  Future<void> ensureInitialized({
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    if (_initialized) return;
    await getShelf(requestScope: requestScope, priority: priority);
  }

  Future<List<ShelfItem>> getShelf({
    bool forceRefresh = true,
    String? requestScope,
    RequestPriority priority = RequestPriority.normal,
  }) async {
    try {
      if (!forceRefresh && _initialized) {
        return _shelfCache.map((e) => ShelfItem.fromJson(e)).toList();
      }

      if (forceRefresh) {
        await _waitForPendingShelfSync();
      }

      final result = await _signalRService.invoke<Map<dynamic, dynamic>>(
        'GetBookShelf',
        requestScope: requestScope,
        priority: priority,
        args: <Object>[
          {},
          {'UseGzip': true},
        ],
      );

      if (result.isEmpty) {
        _logger.warning('Empty shelf response from server');
        if (_initialized) {
          return _shelfCache.map((e) => ShelfItem.fromJson(e)).toList();
        }
        return _initializeEmptyShelf();
      }

      final data = result['data'] ?? result['Data'];
      if (data == null) {
        _logger.warning(
          'Null shelf payload from server, treating as empty shelf',
        );
        if (_initialized) {
          return _shelfCache.map((e) => ShelfItem.fromJson(e)).toList();
        }
        return _initializeEmptyShelf();
      }

      if (data is! List) {
        _logger.warning('Unexpected shelf data type: ${data?.runtimeType}');
        if (_initialized) {
          return _shelfCache.map((e) => ShelfItem.fromJson(e)).toList();
        }
        return [];
      }

      _shelfCache = _squeezeShelfItemIndices(
        data
            .map(
              (e) =>
                  _normalizeShelfItemMap(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
      _initialized = true;

      _logger.info('Parsed ${data.length} shelf items');
      notifyListeners();

      return _shelfCache.map((e) => ShelfItem.fromJson(e)).toList();
    } catch (e) {
      if (isRequestCancelledError(e)) rethrow;
      _logger.severe('Failed to get shelf: $e');
      if (_initialized) {
        return _shelfCache.map((e) => ShelfItem.fromJson(e)).toList();
      }
      return [];
    }
  }

  List<ShelfItem> getShelfItems() {
    if (!_initialized) return [];

    final rawItems = _cloneShelfCache(_shelfCache)..sort(_compareShelfItems);
    return rawItems.map((e) => ShelfItem.fromJson(e)).toList();
  }

  List<ShelfItem> getShelfItemsByParents(List<String> parents) {
    if (!_initialized) return [];

    final normalizedParents = _normalizeParents(parents);
    final rawItems = _cloneShelfCache(
      _shelfCache.where(
        (item) => _parentsEqual(_rawParents(item), normalizedParents),
      ),
    )..sort(_compareShelfItems);

    return rawItems.map((e) => ShelfItem.fromJson(e)).toList();
  }

  List<ShelfItem> getAllBookItemsInDisplayOrder() {
    if (!_initialized) return [];

    final books = <ShelfItem>[];

    void collectBooks(List<String> parents) {
      final items = getShelfItemsByParents(parents);
      for (final item in items) {
        if (item.type == ShelfItemType.book) {
          books.add(item);
          continue;
        }

        final folderId = item.id as String;
        collectBooks([...parents, folderId]);
      }
    }

    collectBooks(const []);
    return books;
  }

  List<ShelfItem> getFolders({String? excludeFolderId}) {
    if (!_initialized) return [];

    final rawItems = _cloneShelfCache(
      _shelfCache.where(
        (item) =>
            _itemType(item) == 'FOLDER' && _itemId(item) != excludeFolderId,
      ),
    )..sort(_compareShelfItems);

    return rawItems.map((e) => ShelfItem.fromJson(e)).toList();
  }

  ShelfItem? getFolderById(String folderId) {
    if (!_initialized) return null;

    for (final item in _shelfCache) {
      if (_itemType(item) == 'FOLDER' && _itemId(item) == folderId) {
        return ShelfItem.fromJson(item);
      }
    }

    return null;
  }

  int getDirectChildCount(String folderId) {
    if (!_initialized) return 0;

    return _shelfCache.where((item) {
      final parents = _rawParents(item);
      return parents.isNotEmpty && parents.last == folderId;
    }).length;
  }

  List<int> getDirectChildBookIds(String folderId, {int limit = 4}) {
    if (!_initialized) return const [];

    final items = _cloneShelfCache(
      _shelfCache.where((item) {
        final parents = _rawParents(item);
        return _itemType(item) == 'BOOK' &&
            parents.isNotEmpty &&
            parents.last == folderId;
      }),
    )..sort(_compareShelfItems);

    return items
        .take(limit)
        .map((item) => int.tryParse(_itemId(item) ?? ''))
        .whereType<int>()
        .toList();
  }

  int getNestedBookCount(String folderId) {
    if (!_initialized) return 0;

    return _shelfCache.where((item) {
      if (_itemType(item) != 'BOOK') {
        return false;
      }

      return _rawParents(item).contains(folderId);
    }).length;
  }

  int getSelectedBookImpactCount({
    Iterable<int> bookIds = const [],
    Iterable<String> folderIds = const [],
  }) {
    if (!_initialized) return 0;

    final selectedBookIds = bookIds.map((id) => '$id').toSet();
    final selectedFolderIds = folderIds.where((id) => id.isNotEmpty).toSet();
    final impactedBookIds = <String>{};

    for (final item in _shelfCache) {
      if (_itemType(item) != 'BOOK') {
        continue;
      }

      final itemId = _itemId(item);
      if (itemId == null || itemId.isEmpty) {
        continue;
      }

      final parents = _rawParents(item);
      if (selectedBookIds.contains(itemId) ||
          parents.any(selectedFolderIds.contains)) {
        impactedBookIds.add(itemId);
      }
    }

    return impactedBookIds.length;
  }

  List<String> getFolderTitles(List<String> folderIds) {
    if (!_initialized) return [];

    final folderMap = <String, String>{};
    for (final item in _shelfCache) {
      if (_itemType(item) != 'FOLDER') {
        continue;
      }

      final id = _itemId(item);
      if (id == null || id.isEmpty) {
        continue;
      }

      folderMap[id] = (item['title'] ?? item['Title']) as String? ?? '';
    }

    return folderIds
        .map((id) => folderMap[id] ?? '')
        .where((title) => title.isNotEmpty)
        .toList();
  }

  Future<bool> addToShelf(int bookId) async {
    try {
      await ensureInitialized();

      final exists = _shelfCache.any(
        (e) => _itemId(e) == '$bookId' && _itemType(e) == 'BOOK',
      );
      if (exists) {
        _logger.info('Book $bookId already in shelf');
        return true;
      }

      final nextShelf = _cloneShelfCache(_shelfCache);
      for (final item in nextShelf) {
        if (_rawParents(item).isEmpty) {
          item['index'] = _rawIndex(item) + 1;
        }
      }

      nextShelf.add({
        'type': 'BOOK',
        'id': bookId,
        'index': 0,
        'parents': <String>[],
        'updateAt': DateTime.now().toIso8601String(),
      });

      _shelfCache = _squeezeShelfItemIndices(nextShelf);

      final syncFuture = _saveShelfToServer();
      notifyListeners();
      await syncFuture;

      _logger.info('Added book $bookId to shelf');
      return true;
    } catch (e) {
      _logger.severe('Failed to add to shelf: $e');
      return false;
    }
  }

  Future<String?> createFolder(String name) async {
    try {
      await ensureInitialized();

      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        _logger.warning('Skipped creating shelf folder with empty name');
        return null;
      }

      final exists = _shelfCache.any(
        (item) =>
            _itemType(item) == 'FOLDER' &&
            ((item['title'] ?? item['Title']) as String? ?? '').trim() ==
                trimmedName,
      );
      if (exists) {
        _logger.info('Shelf folder "$trimmedName" already exists');
        return null;
      }

      final nextShelf = _cloneShelfCache(_shelfCache);
      for (final item in nextShelf) {
        if (_rawParents(item).isEmpty) {
          item['index'] = _rawIndex(item) + 1;
        }
      }

      final folderId = _uuid.v4();
      nextShelf.add({
        'type': 'FOLDER',
        'id': folderId,
        'title': trimmedName,
        'parents': <String>[],
        'index': 0,
        'updateAt': DateTime.now().toIso8601String(),
      });

      _shelfCache = _squeezeShelfItemIndices(nextShelf);

      final syncFuture = _saveShelfToServer();
      notifyListeners();
      await syncFuture;

      _logger.info('Created shelf folder "$trimmedName"');
      return folderId;
    } catch (e) {
      _logger.severe('Failed to create shelf folder: $e');
      return null;
    }
  }

  Future<bool> renameFolder(String folderId, String name) async {
    try {
      await ensureInitialized();

      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        _logger.warning('Skipped renaming shelf folder with empty name');
        return false;
      }

      final nextShelf = _cloneShelfCache(_shelfCache);
      Map<String, dynamic>? targetFolder;
      for (final item in nextShelf) {
        if (_itemType(item) == 'FOLDER' && _itemId(item) == folderId) {
          targetFolder = item;
          break;
        }
      }

      if (targetFolder == null) {
        _logger.warning('Skipped renaming missing shelf folder "$folderId"');
        return false;
      }

      final currentTitle =
          ((targetFolder['title'] ?? targetFolder['Title']) as String? ?? '')
              .trim();
      if (currentTitle == trimmedName) {
        return true;
      }

      final exists = nextShelf.any(
        (item) =>
            _itemType(item) == 'FOLDER' &&
            _itemId(item) != folderId &&
            ((item['title'] ?? item['Title']) as String? ?? '').trim() ==
                trimmedName,
      );
      if (exists) {
        _logger.info('Shelf folder "$trimmedName" already exists');
        return false;
      }

      targetFolder['title'] = trimmedName;
      targetFolder['updateAt'] = DateTime.now().toIso8601String();
      _shelfCache = _squeezeShelfItemIndices(nextShelf);

      final syncFuture = _saveShelfToServer();
      notifyListeners();
      await syncFuture;

      _logger.info('Renamed shelf folder "$folderId" to "$trimmedName"');
      return true;
    } catch (e) {
      _logger.severe('Failed to rename shelf folder: $e');
      return false;
    }
  }

  Future<bool> removeFromShelf(int bookId) async {
    return removeBooksFromShelf([bookId]);
  }

  Future<bool> removeBooksFromShelf(Iterable<int> bookIds) async {
    try {
      await ensureInitialized();
      final targetIds = bookIds.map((id) => '$id').toSet();
      if (targetIds.isEmpty) {
        return true;
      }

      final nextShelf = _cloneShelfCache(_shelfCache)..removeWhere(
        (e) => _itemType(e) == 'BOOK' && targetIds.contains(_itemId(e)),
      );

      if (nextShelf.length == _shelfCache.length) {
        _logger.info('Books ${targetIds.join(',')} were not in shelf');
        return true;
      }

      _shelfCache = _squeezeShelfItemIndices(nextShelf);

      final syncFuture = _saveShelfToServer();
      notifyListeners();
      await syncFuture;

      _logger.info('Removed ${targetIds.length} books from shelf');
      return true;
    } catch (e) {
      _logger.severe('Failed to remove from shelf: $e');
      return false;
    }
  }

  Future<bool> removeSelectionFromShelf({
    Iterable<int> bookIds = const [],
    Iterable<String> folderIds = const [],
  }) async {
    try {
      await ensureInitialized();

      final targetBookIds = bookIds.map((id) => '$id').toSet();
      final targetFolderIds = folderIds.where((id) => id.isNotEmpty).toSet();
      if (targetBookIds.isEmpty && targetFolderIds.isEmpty) {
        return true;
      }

      final nextShelf = _cloneShelfCache(_shelfCache)..removeWhere((item) {
        final itemId = _itemId(item);
        final parents = _rawParents(item);

        if (_itemType(item) == 'BOOK') {
          return targetBookIds.contains(itemId) ||
              parents.any(targetFolderIds.contains);
        }

        return targetFolderIds.contains(itemId) ||
            parents.any(targetFolderIds.contains);
      });

      if (nextShelf.length == _shelfCache.length) {
        _logger.info(
          'Selection remove skipped, no matching items found in shelf',
        );
        return true;
      }

      _shelfCache = _squeezeShelfItemIndices(nextShelf);

      final syncFuture = _saveShelfToServer();
      notifyListeners();
      await syncFuture;

      _logger.info(
        'Removed ${targetBookIds.length} books and ${targetFolderIds.length} folders from shelf',
      );
      return true;
    } catch (e) {
      _logger.severe('Failed to remove selection from shelf: $e');
      return false;
    }
  }

  Future<bool> moveBooksToParents(
    Iterable<int> bookIds,
    List<String> parents,
  ) async {
    try {
      await ensureInitialized();

      final targetIds = bookIds.map((id) => '$id').toSet();
      if (targetIds.isEmpty) {
        return true;
      }

      final normalizedParents = _normalizeParents(parents);
      final nextShelf = _cloneShelfCache(_shelfCache);
      final movingItems =
          nextShelf
              .where(
                (item) =>
                    _itemType(item) == 'BOOK' &&
                    targetIds.contains(_itemId(item)),
              )
              .toList()
            ..sort(_compareShelfItems);

      if (movingItems.isEmpty) {
        _logger.info('No matching books found when moving shelf items');
        return true;
      }

      final movingIds = movingItems.map(_itemId).whereType<String>().toSet();
      final movedCount = movingItems.length;

      for (final item in nextShelf) {
        final itemId = _itemId(item);
        if (_itemType(item) != 'BOOK' || movingIds.contains(itemId)) {
          continue;
        }

        if (_parentsEqual(_rawParents(item), normalizedParents)) {
          item['index'] = _rawIndex(item) + movedCount;
        }
      }

      final now = DateTime.now().toIso8601String();
      for (var i = 0; i < movingItems.length; i++) {
        final item = movingItems[i];
        item['parents'] = List<String>.from(normalizedParents);
        item['index'] = i;
        item['updateAt'] = now;
      }

      _shelfCache = _squeezeShelfItemIndices(nextShelf);

      final syncFuture = _saveShelfToServer();
      notifyListeners();
      await syncFuture;

      _logger.info(
        'Moved ${movingItems.length} books to ${normalizedParents.join('/')}',
      );
      return true;
    } catch (e) {
      _logger.severe('Failed to move books in shelf: $e');
      return false;
    }
  }

  Future<bool> reorderItemsInParents({
    required List<String> parents,
    required int fromIndex,
    required int toIndex,
  }) async {
    try {
      await ensureInitialized();

      final normalizedParents = _normalizeParents(parents);
      final nextShelf = _cloneShelfCache(_shelfCache);
      final siblingItems =
          nextShelf
              .where(
                (item) => _parentsEqual(_rawParents(item), normalizedParents),
              )
              .toList()
            ..sort(_compareShelfItems);

      if (siblingItems.isEmpty ||
          fromIndex < 0 ||
          toIndex < 0 ||
          fromIndex >= siblingItems.length ||
          toIndex >= siblingItems.length ||
          fromIndex == toIndex) {
        return true;
      }

      final movedItem = siblingItems.removeAt(fromIndex);
      siblingItems.insert(toIndex, movedItem);

      final now = DateTime.now().toIso8601String();
      for (var i = 0; i < siblingItems.length; i++) {
        siblingItems[i]['index'] = i;
        siblingItems[i]['updateAt'] = now;
      }

      _shelfCache = _squeezeShelfItemIndices(nextShelf);

      final syncFuture = _saveShelfToServer();
      notifyListeners();
      await syncFuture;

      _logger.info(
        'Reordered ${normalizedParents.isEmpty ? 'root' : normalizedParents.join('/')} from $fromIndex to $toIndex',
      );
      return true;
    } catch (e) {
      _logger.severe('Failed to reorder shelf items: $e');
      return false;
    }
  }

  bool isInShelf(int bookId) {
    if (!_initialized) {
      _logger.warning('isInShelf called before initialization for $bookId');
    }
    return _shelfCache.any(
      (e) => _itemId(e) == '$bookId' && _itemType(e) == 'BOOK',
    );
  }

  Future<List<int>> getReadHistory() async {
    try {
      final result = await _signalRService.invoke<Map<dynamic, dynamic>>(
        'GetReadHistory',
        args: <Object>[
          {},
          {'UseGzip': true},
        ],
      );

      _logger.info('GetReadHistory raw result: $result');

      if (result.isEmpty) {
        _logger.info('Empty read history from server');
        return [];
      }

      final novelList = result['Novel'];
      if (novelList == null || novelList is! List) {
        _logger.warning(
          'Unexpected history data type: ${novelList?.runtimeType}',
        );
        return [];
      }

      final bookIds = novelList.cast<int>().toList();
      _logger.info('Got ${bookIds.length} books in read history');
      return bookIds;
    } catch (e) {
      _logger.severe('Failed to get read history: $e');
      return [];
    }
  }

  Future<bool> clearReadHistory() async {
    try {
      await _signalRService.invoke(
        'ClearReadHistory',
        args: [
          {},
          {'UseGzip': true},
        ],
      );
      _logger.info('Read history cleared');
      notifyListeners();
      return true;
    } catch (e) {
      _logger.severe('Failed to clear read history: $e');
      return false;
    }
  }

  Future<void> _saveShelfToServer() async {
    if (!_initialized) return;

    final snapshot = _squeezeShelfItemIndices(_cloneShelfCache(_shelfCache));
    _shelfCache = snapshot;

    _pendingShelfSync = _pendingShelfSync.catchError((_) {}).then((_) async {
      try {
        await _signalRService.invoke(
          'SaveBookShelf',
          args: <Object>[
            {'data': snapshot, 'ver': '20220211'},
            {'UseGzip': true},
          ],
        );
        _logger.info('Shelf synced to server');
      } catch (e) {
        _logger.severe('Failed to sync shelf to server: $e');
      }
    });

    await _pendingShelfSync;
  }

  Future<void> _waitForPendingShelfSync() async {
    await _pendingShelfSync.catchError((_) {});
  }

  List<ShelfItem> _initializeEmptyShelf() {
    _shelfCache = [];
    _initialized = true;
    notifyListeners();
    return const <ShelfItem>[];
  }

  List<Map<String, dynamic>> _cloneShelfCache(
    Iterable<Map<String, dynamic>> items,
  ) {
    return items.map((item) => Map<String, dynamic>.from(item)).toList();
  }

  List<String> _normalizeParents(Iterable<dynamic> parents) {
    return parents
        .map((parent) => parent.toString())
        .where((parent) => parent.isNotEmpty)
        .toList();
  }

  List<String> _rawParents(Map<String, dynamic> item) {
    final parents = item['parents'] ?? item['Parents'];
    if (parents is! List) {
      return const [];
    }
    return _normalizeParents(parents);
  }

  int _rawIndex(Map<String, dynamic> item) {
    return (item['index'] ?? item['Index']) as int? ?? 0;
  }

  String? _itemId(Map<String, dynamic> item) {
    return (item['id'] ?? item['Id'])?.toString();
  }

  String _itemType(Map<String, dynamic> item) {
    return (item['type'] ?? item['Type']) as String? ?? 'BOOK';
  }

  bool _parentsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  int _compareShelfItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    final indexCompare = _rawIndex(a).compareTo(_rawIndex(b));
    if (indexCompare != 0) {
      return indexCompare;
    }

    final typeCompare = _itemType(a).compareTo(_itemType(b));
    if (typeCompare != 0) {
      return typeCompare;
    }

    return (_itemId(a) ?? '').compareTo(_itemId(b) ?? '');
  }

  List<Map<String, dynamic>> _squeezeShelfItemIndices(
    List<Map<String, dynamic>> items,
  ) {
    final normalized = _cloneShelfCache(items)..sort((a, b) {
      final indexCompare = _rawIndex(a).compareTo(_rawIndex(b));
      if (indexCompare != 0) {
        return indexCompare;
      }
      return _rawParents(a).length.compareTo(_rawParents(b).length);
    });

    final nextIndexByParent = <String, int>{};

    for (final item in normalized) {
      final parents = _rawParents(item);
      item['parents'] = parents;

      final parentKey = parents.isEmpty ? '__ROOT__' : parents.last;
      final nextIndex = (nextIndexByParent[parentKey] ?? -1) + 1;
      nextIndexByParent[parentKey] = nextIndex;
      item['index'] = nextIndex;
    }

    return normalized;
  }

  Map<String, dynamic> _normalizeShelfItemMap(Map<String, dynamic> item) {
    return {
      'id': item['id'] ?? item['Id'],
      'type': item['type'] ?? item['Type'] ?? 'BOOK',
      'title': item['title'] ?? item['Title'] ?? '',
      'parents': _rawParents(item),
      'index': _rawIndex(item),
      'updateAt': item['updateAt'] ?? item['UpdateAt'] ?? '',
    };
  }
}
