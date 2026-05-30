import 'package:flutter_test/flutter_test.dart';
import 'package:novella/data/services/book_search_mode.dart';
import 'package:novella/features/search/search_page.dart';

void main() {
  test('accepts explicit initial search mode', () {
    const page = SearchPage(
      initialKeyword: 'author-name',
      initialMode: BookSearchMode.author,
    );

    expect(page.initialMode, BookSearchMode.author);
  });

  test('accepts tags initial search mode', () {
    const page = SearchPage(
      initialKeyword: 'isekai',
      initialMode: BookSearchMode.tags,
    );

    expect(page.initialMode, BookSearchMode.tags);
  });

  test('keeps initialExact compatibility', () {
    const page = SearchPage(initialKeyword: 'book-title', initialExact: true);

    expect(page.initialMode, BookSearchMode.exact);
  });
}
