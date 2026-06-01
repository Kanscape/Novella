import 'package:flutter_test/flutter_test.dart';
import 'package:novella/core/sync/settings_sync_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('applies synced theme color controls', () async {
    final prefs = await SharedPreferences.getInstance();
    await SettingsSyncCodec.setEnabled(prefs, true);

    final changed =
        await SettingsSyncCodec.applyRemoteSettingsIfEnabled(prefs, {
          'setting_theme': 'dark',
          'setting_seedColorValue': 0xFF0061A4,
          'setting_useSystemColor': false,
          'setting_dynamicSchemeVariant': 3,
        }, DateTime.utc(2026, 1, 2));

    expect(changed, isTrue);
    expect(prefs.getString('setting_theme'), 'dark');
    expect(prefs.getInt('setting_seedColorValue'), 0xFF0061A4);
    expect(prefs.getBool('setting_useSystemColor'), isFalse);
    expect(prefs.getInt('setting_dynamicSchemeVariant'), 3);
  });
}
