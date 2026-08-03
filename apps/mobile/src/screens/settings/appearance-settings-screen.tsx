import { router } from 'expo-router';

import { NativeGroupedList, NativeGroupedListSection } from '@/components/native-grouped-list';
import { NativePickerRow, NativeToggleRow } from '@/components/native-setting-controls';
import { updateAppSettings, useAppSettings } from '@/services/settings';

export function AppearanceSettingsScreen() {
  const settings = useAppSettings();

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="appearance-settings"
      title="Appearance"
    >
      <NativeGroupedListSection title="Theme">
        <NativePickerRow
          description="Follow the device or choose a fixed appearance"
          icon="theme"
          onValueChange={(value) => void updateAppSettings({ theme: value })}
          options={[
            { label: 'System', value: 'system' },
            { label: 'Light', value: 'light' },
            { label: 'Dark', value: 'dark' },
          ] as const}
          selectedValue={settings.theme}
          title="App appearance"
        />
        <NativeToggleRow
          description="Use the cover color on book detail pages"
          icon="coverColor"
          onValueChange={(value) => void updateAppSettings({ coverColorExtraction: value })}
          title="Cover color extraction"
          value={settings.coverColorExtraction}
        />
        {process.env.EXPO_OS === 'android' ? (
          <NativeToggleRow
            description="Use the device wallpaper colors"
            icon="systemColors"
            onValueChange={(value) => void updateAppSettings({ useSystemColor: value })}
            title="System colors"
            value={settings.useSystemColor}
          />
        ) : null}
        <NativeToggleRow
          description="Use a pure black background in dark mode"
          icon="oledBlack"
          onValueChange={(value) => void updateAppSettings({ oledBlack: value })}
          title="OLED black"
          value={settings.oledBlack}
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}
