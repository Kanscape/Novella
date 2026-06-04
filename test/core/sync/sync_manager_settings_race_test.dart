import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/sync/sync_data_model.dart';
import 'package:novella/core/sync/sync_manager.dart';

void main() {
  test('refreshes settings module when local settings change during sync', () {
    final collectedSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 1),
      data: {'setting_theme': 'light'},
    );
    final currentSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 3),
      data: {'setting_theme': 'dark'},
    );
    final localData = SyncData(
      schemaVersion: SyncData.currentSchemaVersion,
      appVersion: 'test',
      syncedAt: DateTime.utc(2026, 1, 1),
      syncId: 'local',
      modules: {SyncModuleNames.settings: collectedSettings},
    );

    final refreshed = refreshLocalSettingsModuleForSync(
      localData: localData,
      trackedSettingsModule: collectedSettings,
      currentSettingsModule: currentSettings,
      shouldAdoptCloudSettings: false,
    );

    expect(
      refreshed.modules[SyncModuleNames.settings]!.data['setting_theme'],
      'dark',
    );
    expect(
      refreshed.modules[SyncModuleNames.settings]!.updatedAt,
      DateTime.utc(2026, 1, 3),
    );
  });

  test('does not refresh settings module during cloud adoption', () {
    final collectedSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 1),
      data: {'setting_theme': 'light'},
    );
    final currentSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 3),
      data: {'setting_theme': 'dark'},
    );
    final localData = SyncData(
      schemaVersion: SyncData.currentSchemaVersion,
      appVersion: 'test',
      syncedAt: DateTime.utc(2026, 1, 1),
      syncId: 'local',
      modules: {SyncModuleNames.settings: collectedSettings},
    );

    final refreshed = refreshLocalSettingsModuleForSync(
      localData: localData,
      trackedSettingsModule: collectedSettings,
      currentSettingsModule: currentSettings,
      shouldAdoptCloudSettings: true,
    );

    expect(
      refreshed.modules[SyncModuleNames.settings]!.data['setting_theme'],
      'light',
    );
  });

  test('uses latest adoption state when refreshing settings module', () {
    final collectedSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 1),
      data: {'setting_theme': 'light'},
    );
    final newlyEnabledLocalSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 3),
      data: {'setting_theme': 'system'},
    );
    final localData = SyncData(
      schemaVersion: SyncData.currentSchemaVersion,
      appVersion: 'test',
      syncedAt: DateTime.utc(2026, 1, 1),
      syncId: 'local',
      modules: {SyncModuleNames.settings: collectedSettings},
    );

    final refreshed = refreshLocalSettingsModuleForSync(
      localData: localData,
      trackedSettingsModule: collectedSettings,
      currentSettingsModule: newlyEnabledLocalSettings,
      shouldAdoptCloudSettings: false,
      latestShouldAdoptCloudSettings: true,
    );

    expect(
      refreshed.modules[SyncModuleNames.settings]!.data['setting_theme'],
      'light',
    );
  });

  test('skips applying settings when local settings change after merge', () {
    final mergedLocalSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 2),
      data: {'setting_theme': 'light'},
    );
    final currentSettings = SyncModule(
      version: 1,
      updatedAt: DateTime.utc(2026, 1, 3),
      data: {'setting_theme': 'dark'},
    );

    final shouldApply = shouldApplySettingsModuleForSync(
      trackedSettingsModule: mergedLocalSettings,
      currentSettingsModule: currentSettings,
      shouldAdoptCloudSettings: false,
    );

    expect(shouldApply, isFalse);
  });
}
