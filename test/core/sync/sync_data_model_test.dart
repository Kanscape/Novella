import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/sync/sync_data_model.dart';

void main() {
  test('merges reading progress by book updatedAt', () {
    final local = SyncData(
      schemaVersion: SyncData.currentSchemaVersion,
      appVersion: 'test',
      syncedAt: DateTime.utc(2026, 1, 3),
      syncId: 'local',
      modules: {
        SyncModuleNames.readingProgress: SyncModule(
          version: 1,
          updatedAt: DateTime.utc(2026, 1, 3),
          data: {
            '1': {
              'bookId': 1,
              'chapterId': 10,
              'sortNum': 1,
              'xPath': 'local-book-1',
              'updatedAt': DateTime.utc(2026, 1, 3).toIso8601String(),
            },
            '2': {
              'bookId': 2,
              'chapterId': 20,
              'sortNum': 2,
              'xPath': 'local-book-2',
              'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
          },
        ),
      },
    );

    final remote = SyncData(
      schemaVersion: SyncData.currentSchemaVersion,
      appVersion: 'test',
      syncedAt: DateTime.utc(2026, 1, 2),
      syncId: 'remote',
      modules: {
        SyncModuleNames.readingProgress: SyncModule(
          version: 1,
          updatedAt: DateTime.utc(2026, 1, 2),
          data: {
            '1': {
              'bookId': 1,
              'chapterId': 11,
              'sortNum': 1,
              'xPath': 'remote-book-1',
              'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
            },
            '2': {
              'bookId': 2,
              'chapterId': 21,
              'sortNum': 3,
              'xPath': 'remote-book-2',
              'updatedAt': DateTime.utc(2026, 1, 4).toIso8601String(),
            },
          },
        ),
      },
    );

    final merged = local.mergeWith(remote);
    final progress = merged.modules[SyncModuleNames.readingProgress]!.data;

    expect(progress['1']['xPath'], 'local-book-1');
    expect(progress['2']['xPath'], 'remote-book-2');
  });
}
