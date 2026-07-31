import { router } from 'expo-router';

import {
  NativeGroupedList,
  NativeGroupedListSection,
} from '@/components/native-grouped-list';
import {
  NativePickerRow,
  NativeSliderRow,
  NativeToggleRow,
} from '@/components/native-setting-controls';
import { updateAppSettings, useAppSettings } from '@/services/settings';

export function ReaderSettingsScreen() {
  const settings = useAppSettings();

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="reader-settings"
      title="Reading"
    >
      <NativeGroupedListSection title="Typography">
        <NativeSliderRow
          description="Text size used by the novel reader"
          formatValue={(value) => `${Math.round(value)} pt`}
          icon="reader"
          max={32}
          min={12}
          onValueChange={(value) => void updateAppSettings({ fontSize: value })}
          step={1}
          title="Font size"
          value={settings.fontSize}
        />
        <NativeSliderRow
          description="Space between lines in a paragraph"
          formatValue={(value) => `${value.toFixed(1)}x`}
          icon="reader"
          max={2.5}
          min={1}
          onValueChange={(value) => void updateAppSettings({ readerLineHeight: value })}
          step={0.1}
          title="Line height"
          value={settings.readerLineHeight}
        />
        <NativeSliderRow
          description="Horizontal padding around reader content"
          formatValue={(value) => `${Math.round(value)} pt`}
          icon="reader"
          max={64}
          min={12}
          onValueChange={(value) => void updateAppSettings({ readerSidePadding: value })}
          step={1}
          title="Side padding"
          value={settings.readerSidePadding}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Reading behavior">
        <NativePickerRow
          description="Choose scrolling or page-by-page navigation"
          icon="reader"
          onValueChange={(value) => void updateAppSettings({ readerViewMode: value })}
          options={[
            { label: 'Paged', value: 'paged' },
            { label: 'Scroll', value: 'scroll' },
          ] as const}
          selectedValue={settings.readerViewMode}
          title="Reading mode"
        />
        <NativeToggleRow
          description="Indent the first line of each paragraph"
          icon="reader"
          onValueChange={(value) => void updateAppSettings({ readerFirstLineIndent: value })}
          title="First-line indent"
          value={settings.readerFirstLineIndent}
        />
        <NativeToggleRow
          description="Keep page changes still in paged mode"
          icon="reader"
          onValueChange={(value) => void updateAppSettings({ readerPagedNoAnimation: value })}
          title="Disable page animation"
          value={settings.readerPagedNoAnimation}
        />
        <NativeToggleRow
          description="Open image previews with a long press"
          icon="reader"
          onValueChange={(value) => void updateAppSettings({ readerImagePreviewOpenOnLongPress: value })}
          title="Long-press image preview"
          value={settings.readerImagePreviewOpenOnLongPress}
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}
