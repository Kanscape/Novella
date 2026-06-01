import 'package:flutter_test/flutter_test.dart';
import 'package:novella/data/services/reading_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getLastReadBook ignores stale last_read_book_id', () async {
    SharedPreferences.setMockInitialValues({
      'last_read_book_id': 1,
      'read_pos_1':
          '10|1|book-1|${DateTime.utc(2026, 1, 1).toIso8601String()}|Book 1|cover-1|Chapter 1',
      'read_pos_2':
          '20|2|book-2|${DateTime.utc(2026, 1, 3).toIso8601String()}|Book 2|cover-2|Chapter 2',
    });

    final service = ReadingProgressService();

    final lastRead = await service.getLastReadBook();

    expect(lastRead?.bookId, 2);
    expect(lastRead?.xPath, 'book-2');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('last_read_book_id'), 2);
  });
}
