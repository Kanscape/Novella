const appDisplayModeAutoValue = '#0 0x0 @ 0Hz';
const _legacyDisplayModeAutoValue = 'auto';

String resolveDisplayModePreference(
  String? savedValue, {
  required Iterable<String> supportedValues,
  required String autoValue,
}) {
  if (savedValue == null ||
      savedValue.isEmpty ||
      savedValue == _legacyDisplayModeAutoValue) {
    return autoValue;
  }

  if (supportedValues.contains(savedValue)) {
    return savedValue;
  }

  return autoValue;
}

String displayModeLabel(
  String value, {
  required String autoValue,
  String? activeValue,
}) {
  if (value == autoValue || value == _legacyDisplayModeAutoValue) {
    return '自动';
  }
  if (activeValue == value) {
    return '$value [系统]';
  }
  return value;
}
