import { router } from 'expo-router';

import {
  NativeGroupedList,
  NativeGroupedListRow,
  NativeGroupedListSection,
} from '@/components/native-grouped-list';
import { NativePickerRow, NativeToggleRow } from '@/components/native-setting-controls';
import {
  RANK_PERIOD_OPTIONS,
  updateAppSettings,
  useAppSettings,
} from '@/services/settings';

export function ContentSettingsScreen() {
  const settings = useAppSettings();

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="content-settings"
      title="Content"
    >
      <NativeGroupedListSection title="Home">
        <NativePickerRow
          description="Choose which leaderboard the home screen shows"
          icon="ranking"
          onValueChange={(value) => void updateAppSettings({ homeRankType: value })}
          options={RANK_PERIOD_OPTIONS}
          selectedValue={settings.homeRankType}
          title="Home ranking"
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Content filters">
        <NativeToggleRow
          description="Hide Japanese titles from discovery lists"
          icon="japanese"
          onValueChange={(value) => void updateAppSettings({ ignoreJapanese: value })}
          title="Hide Japanese content"
          value={settings.ignoreJapanese}
        />
        <NativeToggleRow
          description="Hide AI-tagged books from discovery lists"
          icon="aiContent"
          onValueChange={(value) => void updateAppSettings({ ignoreAI: value })}
          title="Hide AI content"
          value={settings.ignoreAI}
        />
        <NativeToggleRow
          description="Hide Level 6 books from discovery lists"
          icon="level6Content"
          onValueChange={(value) => void updateAppSettings({ ignoreLevel6: value })}
          title="Hide Level 6 content"
          value={settings.ignoreLevel6}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Book badges">
        <NativeGroupedListRow
          description="Preview all book-cover badges and their meanings"
          icon="badges"
          onPress={() => router.push('/settings/badges')}
          title="Badge meanings"
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Text conversion">
        <NativePickerRow
          description="Convert text while reading"
          icon="textConvert"
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
