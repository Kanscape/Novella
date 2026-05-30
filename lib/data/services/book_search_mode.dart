enum BookSearchMode { fuzzy, exact, title, author, name, tags }

bool isQuotedBookSearchKeyword(String keyword) {
  final trimmed = keyword.trim();
  return trimmed.length >= 2 &&
      trimmed.startsWith('"') &&
      trimmed.endsWith('"');
}

extension BookSearchModeRequest on BookSearchMode {
  String get methodName {
    return switch (this) {
      BookSearchMode.fuzzy => 'GetBookList',
      BookSearchMode.exact => 'GetBookList',
      BookSearchMode.title => 'GetBookListByTitle',
      BookSearchMode.author => 'GetBookListByAuthor',
      BookSearchMode.name => 'GetBookListByName',
      BookSearchMode.tags => 'GetBookListByTags',
    };
  }

  String buildRequestKeyword(String keyword) {
    final trimmed = keyword.trim();
    if (this != BookSearchMode.exact || trimmed.isEmpty) {
      return trimmed;
    }
    return '"$trimmed"';
  }
}
