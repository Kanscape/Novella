import 'package:novella/data/models/book.dart';

const _japaneseCategoryNames = {'日文原版'};
const _japaneseCategoryShortNames = {'日文', '日原', '日文原版'};
const _aiCategoryNames = {'AI翻译'};
const _aiCategoryShortNames = {'AI', 'AI翻译'};

List<Book> filterBooksByContentSettings(
  Iterable<Book> books, {
  required bool ignoreJapanese,
  required bool ignoreAI,
  required bool ignoreLevel6,
}) {
  if (!ignoreJapanese && !ignoreAI && !ignoreLevel6) {
    return books.toList();
  }

  return books.where((book) {
    if (ignoreLevel6 && book.level == 6) {
      return false;
    }

    final category = book.category;
    if (category == null) {
      return true;
    }

    if (ignoreJapanese &&
        _matchesCategory(
          category,
          names: _japaneseCategoryNames,
          shortNames: _japaneseCategoryShortNames,
        )) {
      return false;
    }

    if (ignoreAI &&
        _matchesCategory(
          category,
          names: _aiCategoryNames,
          shortNames: _aiCategoryShortNames,
        )) {
      return false;
    }

    return true;
  }).toList();
}

bool _matchesCategory(
  BookCategory category, {
  required Set<String> names,
  required Set<String> shortNames,
}) {
  final name = category.name.trim();
  final shortName = category.shortName.trim();
  return names.contains(name) || shortNames.contains(shortName);
}
