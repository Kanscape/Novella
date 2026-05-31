import 'package:flutter_test/flutter_test.dart';
import 'package:novella/data/models/book.dart';
import 'package:novella/data/services/book_content_filter.dart';

void main() {
  group('filterBooksByContentSettings', () {
    test('removes Japanese, AI, and Level6 books when filters are enabled', () {
      final books = [
        _book(
          1,
          category: const BookCategory(
            shortName: '日文',
            name: '日文原版',
            color: '',
          ),
        ),
        _book(
          2,
          category: const BookCategory(
            shortName: 'AI',
            name: 'AI翻译',
            color: '',
          ),
        ),
        _book(3, level: 6),
        _book(
          4,
          category: const BookCategory(
            shortName: '录入',
            name: '录入完成',
            color: '',
          ),
        ),
        _book(5),
      ];

      final filtered = filterBooksByContentSettings(
        books,
        ignoreJapanese: true,
        ignoreAI: true,
        ignoreLevel6: true,
      );

      expect(filtered.map((book) => book.id), [4, 5]);
    });

    test('keeps books when matching filters are disabled', () {
      final books = [
        _book(
          1,
          category: const BookCategory(
            shortName: '日文',
            name: '日文原版',
            color: '',
          ),
        ),
        _book(
          2,
          category: const BookCategory(
            shortName: 'AI',
            name: 'AI翻译',
            color: '',
          ),
        ),
        _book(3, level: 6),
      ];

      final filtered = filterBooksByContentSettings(
        books,
        ignoreJapanese: false,
        ignoreAI: false,
        ignoreLevel6: false,
      );

      expect(filtered.map((book) => book.id), [1, 2, 3]);
    });
  });
}

Book _book(int id, {BookCategory? category, int? level}) {
  return Book(
    id: id,
    title: 'Book $id',
    cover: '',
    author: '',
    lastUpdatedAt: DateTime.utc(2026),
    category: category,
    level: level,
  );
}
