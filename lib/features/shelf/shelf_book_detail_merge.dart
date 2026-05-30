import 'package:novella/data/models/book.dart';

class ShelfBookDetailMergeResult {
  const ShelfBookDetailMergeResult({
    required this.bookDetails,
    required this.invalidBookIds,
  });

  final Map<int, Book> bookDetails;
  final Set<int> invalidBookIds;
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
