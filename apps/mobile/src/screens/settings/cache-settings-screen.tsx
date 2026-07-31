import { router } from 'expo-router';

import { NativeGroupedList, NativeGroupedListSection } from '@/components/native-grouped-list';
import { NativeSliderRow, NativeToggleRow } from '@/components/native-setting-controls';
import { updateAppSettings, useAppSettings } from '@/services/settings';

export function CacheSettingsScreen() {
  const settings = useAppSettings();

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="cache-settings"
      title="Cache"
    >
      <NativeGroupedListSection title="Local cache">
        <NativeToggleRow
          description="Keep recently opened book details on this device"
          icon="cache"
          onValueChange={(value) => void updateAppSettings({ bookDetailCacheEnabled: value })}
          title="Book detail cache"
          value={settings.bookDetailCacheEnabled}
        />
        <NativeToggleRow
          description="Reuse downloaded font metadata and files"
          icon="cache"
          onValueChange={(value) => void updateAppSettings({ fontCacheEnabled: value })}
          title="Font cache"
          value={settings.fontCacheEnabled}
        />
        <NativeSliderRow
          description="Maximum number of cached font entries"
          formatValue={(value) => `${Math.round(value)} books`}
          icon="cache"
          max={60}
          min={10}
          onValueChange={(value) => void updateAppSettings({ fontCacheLimit: value })}
          step={1}
          title="Font cache limit"
          value={settings.fontCacheLimit}
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}
