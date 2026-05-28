import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementReadStore {
  AnnouncementReadStore({Future<SharedPreferences> Function()? prefsLoader})
    : _prefsLoader = prefsLoader ?? SharedPreferences.getInstance;

  static const String readKeysPreferenceKey = 'announcement_read_keys';

  final Future<SharedPreferences> Function() _prefsLoader;

  Future<Set<String>> readKeys() async {
    final prefs = await _prefsLoader();
    return (prefs.getStringList(readKeysPreferenceKey) ?? const <String>[])
        .toSet();
  }

  Future<bool> isRead(String readKey) async {
    if (readKey.isEmpty) {
      return false;
    }
    final keys = await readKeys();
    return keys.contains(readKey);
  }

  Future<void> markRead(String readKey) async {
    if (readKey.isEmpty) {
      return;
    }
    final prefs = await _prefsLoader();
    final keys =
        (prefs.getStringList(readKeysPreferenceKey) ?? const <String>[])
            .toSet();
    if (!keys.add(readKey)) {
      return;
    }
    await prefs.setStringList(readKeysPreferenceKey, keys.toList()..sort());
  }
}
