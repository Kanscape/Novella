import 'package:novella/data/models/book.dart';

class ShelfBookDetailMergeResult {
  const ShelfBookDetailMergeResult({
    required this.bookDetails,
    required this.invalidBookIds,
  });

  final Map<int, Book> bookDetails;
  final Set<int> invalidBookIds;
}

Set<int> collectShelfActiveDetailIds({
  required Iterable<ShelfItem> items,
  required Iterable<int> Function(String folderId) folderPreviewBookIds,
}) {
  final activeBookIds = <int>{};
  for (final item in items) {
    switch (item.type) {
      case ShelfItemType.book:
        activeBookIds.add(item.id as int);
      case ShelfItemType.folder:
        activeBookIds.addAll(folderPreviewBookIds(item.id as String));
    }
  }
  return activeBookIds;
}

Set<int> collectShelfInitialDetailIds({
  required Iterable<ShelfItem> items,
  required Set<int> cachedBookIds,
  required Set<int> invalidBookIds,
  required Set<int> revalidateBookIds,
  required Iterable<int> Function(String folderId) folderPreviewBookIds,
  int limit = 12,
}) {
  final detailIds = <int>{};

  void collectBookId(int bookId) {
    if (revalidateBookIds.contains(bookId) ||
        (!cachedBookIds.contains(bookId) && !invalidBookIds.contains(bookId))) {
      detailIds.add(bookId);
    }
  }

  for (final item in items.take(limit)) {
    switch (item.type) {
      case ShelfItemType.book:
        collectBookId(item.id as int);
      case ShelfItemType.folder:
        for (final previewId in folderPreviewBookIds(item.id as String)) {
          collectBookId(previewId);
        }
    }
  }

  return detailIds;
}

ShelfBookDetailMergeResult mergeShelfBookDetails({
  required Map<int, Book> currentBookDetails,
  required Set<int> currentInvalidBookIds,
  required Set<int> activeBookIds,
  required List<int> requestedIds,
  required List<Book?> loadedBooks,
}) {
  final nextBookDetails = Map<int, Book>.of(currentBookDetails)
    ..removeWhere((bookId, _) => !activeBookIds.contains(bookId));
  final nextInvalidBookIds = Set<int>.of(currentInvalidBookIds)
    ..removeWhere((bookId) => !activeBookIds.contains(bookId));

  for (var index = 0; index < requestedIds.length; index++) {
    final requestedId = requestedIds[index];
    if (!activeBookIds.contains(requestedId)) {
      continue;
    }

    final book = index < loadedBooks.length ? loadedBooks[index] : null;
    if (book == null) {
      nextBookDetails.remove(requestedId);
      nextInvalidBookIds.add(requestedId);
      continue;
    }

    if (activeBookIds.contains(book.id)) {
      nextBookDetails[book.id] = book;
      nextInvalidBookIds.remove(book.id);
    }
  }

  return ShelfBookDetailMergeResult(
    bookDetails: nextBookDetails,
    invalidBookIds: nextInvalidBookIds,
  );
}
