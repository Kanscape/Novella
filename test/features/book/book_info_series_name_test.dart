import 'package:flutter_test/flutter_test.dart';
import 'package:novella/features/book/book_detail_page.dart';

void main() {
  test('parses Chinese series name from book classification extra', () {
    final info = BookInfo.fromJson({
      'Book': {
        'Id': 578,
        'Title': '公爵千金大小姐的爱好 3',
        'Cover': '',
        'Author': '',
        'Introduction': '',
        'LastUpdatedAt': '2026-05-20T14:04:06.8181455Z',
        'Favorite': 23,
        'Views': 0,
        'CanEdit': false,
        'Chapter': [],
        'Extra': {
          'classification': {
            'series_name': '公爵令嬢の嗜み',
            'series_name_cn': '公爵家千金大小姐的爱好',
          },
        },
      },
    });

    expect(info.seriesName, '公爵家千金大小姐的爱好');
  });

  test('parses tags from book classification extra', () {
    final info = BookInfo.fromJson({
      'Book': {
        'Id': 578,
        'Title': '公爵千金大小姐的爱好 3',
        'Cover': '',
        'Author': '',
        'Introduction': '',
        'LastUpdatedAt': '2026-05-20T14:04:06.8181455Z',
        'Favorite': 23,
        'Views': 0,
        'CanEdit': false,
        'Chapter': [],
        'Extra': {
          'classification': {
            'tags': ['转生', ' 恶役千金 ', '', '异世界'],
          },
        },
      },
    });

    expect(info.tags, ['转生', '恶役千金', '异世界']);
  });

  test('falls back to original series name when Chinese name is missing', () {
    final info = BookInfo.fromJson({
      'Book': {
        'Id': 578,
        'Title': '公爵令嬢の嗜み 3',
        'Cover': '',
        'Author': '',
        'Introduction': '',
        'LastUpdatedAt': '2026-05-20T14:04:06.8181455Z',
        'Favorite': 23,
        'Views': 0,
        'CanEdit': false,
        'Chapter': [],
        'Extra': {
          'classification': {'series_name': '公爵令嬢の嗜み'},
        },
      },
    });

    expect(info.seriesName, '公爵令嬢の嗜み');
  });

  test('keeps series name null when classification is unavailable', () {
    final info = BookInfo.fromJson({
      'Book': {
        'Id': 578,
        'Title': '新书标题 1',
        'Cover': '',
        'Author': '',
        'Introduction': '',
        'LastUpdatedAt': '2026-05-20T14:04:06.8181455Z',
        'Favorite': 23,
        'Views': 0,
        'CanEdit': false,
        'Chapter': [],
      },
    });

    expect(info.seriesName, isNull);
    expect(info.tags, isEmpty);
  });
}
