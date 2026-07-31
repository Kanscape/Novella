import { router } from 'expo-router';

import { NativeGroupedList, NativeGroupedListSection } from '@/components/native-grouped-list';
import { NativePickerRow, NativeToggleRow } from '@/components/native-setting-controls';
import { updateAppSettings, useAppSettings } from '@/services/settings';

export function ContentSettingsScreen() {
  const settings = useAppSettings();

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="content-settings"
      title="Content"
    >
      <NativeGroupedListSection title="Content filters">
        <NativeToggleRow
          description="Hide Japanese titles from discovery lists"
          icon="content"
          onValueChange={(value) => void updateAppSettings({ ignoreJapanese: value })}
          title="Hide Japanese content"
          value={settings.ignoreJapanese}
        />
        <NativeToggleRow
          description="Hide AI-tagged books from discovery lists"
          icon="content"
          onValueChange={(value) => void updateAppSettings({ ignoreAI: value })}
          title="Hide AI content"
          value={settings.ignoreAI}
        />
        <NativeToggleRow
          description="Hide Level 6 books from discovery lists"
          icon="content"
          onValueChange={(value) => void updateAppSettings({ ignoreLevel6: value })}
          title="Hide Level 6 content"
          value={settings.ignoreLevel6}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Text conversion">
        <NativePickerRow
          description="Convert text while reading"
          icon="content"
          onValueChange={(value) => void updateAppSettings({ convertType: value })}
          options={[
            { label: 'Off', value: 'none' },
            { label: 'Traditional to Simplified', value: 't2s' },
            { label: 'Simplified to Traditional', value: 's2t' },
          ] as const}
          selectedValue={settings.convertType}
          title="Chinese conversion"
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}
