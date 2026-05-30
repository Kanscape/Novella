import 'package:flutter_test/flutter_test.dart';
import 'package:novella/data/services/book_search_mode.dart';
import 'package:novella/features/search/search_page.dart';

void main() {
  test('accepts explicit initial search mode', () {
    const page = SearchPage(
      initialKeyword: '作者名',
      initialMode: BookSearchMode.author,
    );

    expect(page.initialMode, BookSearchMode.author);
  });

  test('keeps initialExact compatibility', () {
    const page = SearchPage(initialKeyword: '书名', initialExact: true);

    expect(page.initialMode, BookSearchMode.exact);
  });
}
