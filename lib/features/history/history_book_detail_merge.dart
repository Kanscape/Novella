import 'package:novella/data/models/book.dart';

class HistoryBookDetailMergeResult {
  const HistoryBookDetailMergeResult({
    required this.bookIds,
    required this.bookDetails,
    required this.missingBookIds,
  });

  final List<int> bookIds;
  final Map<int, Book> bookDetails;
  final Set<int> missingBookIds;
}

HistoryBookDetailMergeResult mergeHistoryBookDetails({
  required List<int> currentBookIds,
  required Map<int, Book> currentBookDetails,
  required List<int> requestedIds,
  required List<Book?> loadedBooks,
}) {
  final activeBookIds = currentBookIds.toSet();
  final missingBookIds = <int>{};
  final nextBookDetails = Map<int, Book>.of(currentBookDetails)
    ..removeWhere((bookId, _) => !activeBookIds.contains(bookId));

  for (var index = 0; index < requestedIds.length; index++) {
    final requestedId = requestedIds[index];
    final book = index < loadedBooks.length ? loadedBooks[index] : null;

    if (book == null) {
      missingBookIds.add(requestedId);
      continue;
    }

    if (activeBookIds.contains(book.id)) {
      nextBookDetails[book.id] = book;
    }
  }

  if (missingBookIds.isEmpty) {
    return HistoryBookDetailMergeResult(
      bookIds: List<int>.of(currentBookIds),
      bookDetails: nextBookDetails,
      missingBookIds: const <int>{},
    );
  }

  return HistoryBookDetailMergeResult(
    bookIds: currentBookIds
        .where((bookId) => !missingBookIds.contains(bookId))
        .toList(growable: false),
    bookDetails: nextBookDetails,
    missingBookIds: missingBookIds,
  );
}
