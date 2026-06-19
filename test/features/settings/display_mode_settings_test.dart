import 'package:flutter_test/flutter_test.dart';
import 'package:novella/features/settings/display_mode_settings.dart';

void main() {
  group('resolveDisplayModePreference', () {
    const auto = appDisplayModeAutoValue;
    const supported = <String>[
      auto,
      '#1 1080x2400 @ 60Hz',
      '#2 1080x2400 @ 120Hz',
    ];

    test('keeps a supported saved mode', () {
      expect(
        resolveDisplayModePreference(
          '#2 1080x2400 @ 120Hz',
          supportedValues: supported,
          autoValue: auto,
        ),
        '#2 1080x2400 @ 120Hz',
      );
    });

    test('uses auto when saved mode is missing on this device', () {
      expect(
        resolveDisplayModePreference(
          '#7 1440x3168 @ 144Hz',
          supportedValues: supported,
          autoValue: auto,
        ),
        auto,
      );
    });

    test('uses auto for empty saved value', () {
      expect(
        resolveDisplayModePreference(
          '',
          supportedValues: supported,
          autoValue: auto,
        ),
        auto,
      );
    });

    test('normalizes legacy auto value', () {
      expect(
        resolveDisplayModePreference(
          'auto',
          supportedValues: supported,
          autoValue: auto,
        ),
        auto,
      );
    });
  });

  group('displayModeLabel', () {
    test('labels the automatic mode', () {
      expect(
        displayModeLabel(
          appDisplayModeAutoValue,
          autoValue: appDisplayModeAutoValue,
        ),
        '自动',
      );
    });

    test('marks the active system mode', () {
      expect(
        displayModeLabel(
          '#2 1080x2400 @ 120Hz',
          autoValue: appDisplayModeAutoValue,
          activeValue: '#2 1080x2400 @ 120Hz',
        ),
        '#2 1080x2400 @ 120Hz [系统]',
      );
    });
  });
}
