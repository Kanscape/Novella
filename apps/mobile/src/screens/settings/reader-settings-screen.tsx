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
import {
  READER_PRELOAD_WINDOW,
  toggleCleanChapterTitleScope,
  updateAppSettings,
  useAppSettings,
} from '@/services/settings';

export function ReaderSettingsScreen() {
  const settings = useAppSettings();

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="reader-settings"
      title="Reading"
    >
      <ReaderSettingsContent />
    </NativeGroupedList>
  );
}

/** Shared settings rows, also rendered inside the reader settings sheet. */
export function ReaderSettingsContent() {
  const settings = useAppSettings();

  return (
    <>
      <NativeGroupedListSection title="Typography">
        <NativeSliderRow
          description="Text size used by the novel reader"
          formatValue={(value) => `${Math.round(value)} pt`}
          icon="textSize"
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
          icon="lineHeight"
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
          icon="sidePadding"
          max={64}
          min={12}
          onValueChange={(value) => void updateAppSettings({ readerSidePadding: value })}
          step={1}
          title="Side padding"
          value={settings.readerSidePadding}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Chapter titles">
        <NativeToggleRow
          description="Show only the chapter number/name on the continue-reading button"
          icon="clock"
          onValueChange={(value) => void updateAppSettings({
            cleanChapterTitleScopes: toggleCleanChapterTitleScope(
              settings.cleanChapterTitleScopes,
              'continueReading',
              value,
            ),
          })}
          title="Continue reading button"
          value={settings.cleanChapterTitleScopes.includes('continueReading')}
        />
        <NativeToggleRow
          description="Show only the chapter number/name in the reader header"
          icon="reader"
          onValueChange={(value) => void updateAppSettings({
            cleanChapterTitleScopes: toggleCleanChapterTitleScope(
              settings.cleanChapterTitleScopes,
              'readerTitle',
              value,
            ),
          })}
          title="Reader title"
          value={settings.cleanChapterTitleScopes.includes('readerTitle')}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Reading behavior">
        <NativePickerRow
          description="Choose scrolling or page-by-page navigation"
          icon="readingMode"
          onValueChange={(value) => void updateAppSettings({ readerViewMode: value })}
          options={[
            { label: 'Paged', value: 'paged' },
            { label: 'Scroll', value: 'scroll' },
          ] as const}
          selectedValue={settings.readerViewMode}
          title="Reading mode"
        />
        <NativeSliderRow
          description="Upcoming novel chapters prepared while reading"
          formatValue={(value) => {
            const count = Math.round(value);
            return count === 0 ? 'Off' : `${count} chapter${count === 1 ? '' : 's'}`;
          }}
          icon="preload"
          max={READER_PRELOAD_WINDOW.max}
          min={READER_PRELOAD_WINDOW.min}
          onValueChange={(value) => void updateAppSettings({ readerPreloadWindow: value })}
          step={1}
          title="Preload ahead"
          value={settings.readerPreloadWindow}
        />
        <NativeToggleRow
          description="Indent the first line of each paragraph"
          icon="firstLineIndent"
          onValueChange={(value) => void updateAppSettings({ readerFirstLineIndent: value })}
          title="First-line indent"
          value={settings.readerFirstLineIndent}
        />
        <NativeToggleRow
          description="Keep page changes still in paged mode"
          icon="noPageAnimation"
          onValueChange={(value) => void updateAppSettings({ readerPagedNoAnimation: value })}
          title="Disable page animation"
          value={settings.readerPagedNoAnimation}
        />
        <NativeToggleRow
          description="Open image previews with a long press"
          icon="imagePreview"
          onValueChange={(value) => void updateAppSettings({ readerImagePreviewOpenOnLongPress: value })}
          title="Long-press image preview"
          value={settings.readerImagePreviewOpenOnLongPress}
        />
      </NativeGroupedListSection>
    </>
  );
}
