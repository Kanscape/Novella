import 'package:flutter_test/flutter_test.dart';
import 'package:novella/features/book/book_detail_page.dart';
import 'package:novella/features/settings/settings_provider.dart';

void main() {
  test(
    'system mode searches original series for Japanese original category',
    () {
      final book = BookInfo(
        id: 578,
        title: '公爵千金大小姐的爱好 3',
        cover: '',
        author: '',
        seriesName: '公爵家千金大小姐的爱好',
        originalSeriesName: '公爵令嬢の嗜み',
        categoryName: '日文原版',
        introduction: '',
        lastUpdatedAt: DateTime.utc(2026, 5, 20),
        favorite: 23,
        views: 0,
        canEdit: false,
        chapters: const [],
      );

      expect(
        book.resolveSeriesSearchKeyword(SeriesSearchMode.system),
        '公爵令嬢の嗜み',
      );
    },
  );

  test('system mode searches displayed series for non-Japanese category', () {
    final book = BookInfo(
      id: 578,
      title: '公爵千金大小姐的爱好 3',
      cover: '',
      author: '',
      seriesName: '公爵家千金大小姐的爱好',
      originalSeriesName: '公爵令嬢の嗜み',
      categoryName: '录入完成',
      introduction: '',
      lastUpdatedAt: DateTime.utc(2026, 5, 20),
      favorite: 23,
      views: 0,
      canEdit: false,
      chapters: const [],
    );

    expect(
      book.resolveSeriesSearchKeyword(SeriesSearchMode.system),
      '公爵家千金大小姐的爱好',
    );
  });

  test('original mode searches original series whenever present', () {
    final book = BookInfo(
      id: 578,
      title: '公爵千金大小姐的爱好 3',
      cover: '',
      author: '',
      seriesName: '公爵家千金大小姐的爱好',
      originalSeriesName: '公爵令嬢の嗜み',
      categoryName: '录入完成',
      introduction: '',
      lastUpdatedAt: DateTime.utc(2026, 5, 20),
      favorite: 23,
      views: 0,
      canEdit: false,
      chapters: const [],
    );

    expect(
      book.resolveSeriesSearchKeyword(SeriesSearchMode.original),
      '公爵令嬢の嗜み',
    );
  });

  test('display mode searches displayed series', () {
    final book = BookInfo(
      id: 578,
      title: '公爵千金大小姐的爱好 3',
      cover: '',
      author: '',
      seriesName: '公爵家千金大小姐的爱好',
      originalSeriesName: '公爵令嬢の嗜み',
      categoryName: '日文原版',
      introduction: '',
      lastUpdatedAt: DateTime.utc(2026, 5, 20),
      favorite: 23,
      views: 0,
      canEdit: false,
      chapters: const [],
    );

    expect(
      book.resolveSeriesSearchKeyword(SeriesSearchMode.display),
      '公爵家千金大小姐的爱好',
    );
  });
}
