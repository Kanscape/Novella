import 'package:flutter_test/flutter_test.dart';
import 'package:novella/features/reader/shared/reader_preload_policy.dart';

void main() {
  test('initial paged reader display only waits for the requested chapter', () {
    expect(readerInitialDisplaySortNums(sortNum: 12), [12]);
    expect(shouldAwaitAdjacentChaptersForInitialDisplay(), isFalse);
  });

  test('adjacent preload targets stay bounded by available chapters', () {
    expect(readerAdjacentPreloadTargets(sortNum: 1, totalChapters: 3), [2]);
    expect(readerAdjacentPreloadTargets(sortNum: 2, totalChapters: 3), [1, 3]);
    expect(readerAdjacentPreloadTargets(sortNum: 3, totalChapters: 3), [2]);
    expect(readerAdjacentPreloadTargets(sortNum: 1, totalChapters: 1), isEmpty);
  });

  test('adjacent preload is delayed beyond the first rendered frame', () {
    expect(readerAdjacentPreloadDelay, greaterThan(Duration.zero));
  });
}
