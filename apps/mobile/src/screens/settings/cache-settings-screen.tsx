import { Image } from 'expo-image';
import { useState } from 'react';


import { showAlert } from '@/components/native-alert-dialog';
import { router } from 'expo-router';

import { clearBookCoverRevealCache } from '@/components/book-cover-image';
import {
  NativeGroupedList,
  NativeGroupedListRow,
  NativeGroupedListSection,
} from '@/components/native-grouped-list';
import { NativeSliderRow, NativeToggleRow } from '@/components/native-setting-controls';
import { clearReaderFontCache } from '@/services/reader-font-loader';
import { updateAppSettings, useAppSettings } from '@/services/settings';

export function CacheSettingsScreen() {
  const settings = useAppSettings();
  const [clearingFonts, setClearingFonts] = useState(false);
  const [clearingImages, setClearingImages] = useState(false);

  async function handleClearImages() {
    if (clearingImages) return;
    setClearingImages(true);
    try {
      clearBookCoverRevealCache();
      const [memoryCleared, diskCleared] = await Promise.all([
        Image.clearMemoryCache(),
        Image.clearDiskCache(),
      ]);
      if (!memoryCleared || !diskCleared) {
        throw new Error('One or more native image caches could not be cleared.');
      }
      showAlert(
        'Image cache cleared',
        'Removed downloaded images and decoded BlurHash placeholders.',
      );
    } catch (error) {
      showAlert(
        'Unable to clear images',
        error instanceof Error ? error.message : 'The image cache could not be cleared.',
      );
    } finally {
      setClearingImages(false);
    }
  }

  async function handleClearReaderFonts() {
    if (clearingFonts) return;
    setClearingFonts(true);
    try {
      const entryCount = clearReaderFontCache();
      showAlert(
        'Reader font cache cleared',
        entryCount === 0
          ? 'There were no cached reader fonts.'
          : `Removed ${entryCount} cached font ${entryCount === 1 ? 'file' : 'files'}.`,
      );
    } catch (error) {
      showAlert(
        'Unable to clear reader fonts',
        error instanceof Error ? error.message : 'The cache could not be cleared.',
      );
    } finally {
      setClearingFonts(false);
    }
  }

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
          icon="bookDetailCache"
          onValueChange={(value) => void updateAppSettings({ bookDetailCacheEnabled: value })}
          title="Book detail cache"
          value={settings.bookDetailCacheEnabled}
        />
        <NativeToggleRow
          description="Reuse downloaded font metadata and files"
          icon="fontCache"
          onValueChange={(value) => void updateAppSettings({ fontCacheEnabled: value })}
          title="Font cache"
          value={settings.fontCacheEnabled}
        />
        <NativeSliderRow
          description="Maximum number of cached font entries"
          formatValue={(value) => `${Math.round(value)} books`}
          icon="fontCacheLimit"
          max={60}
          min={10}
          onValueChange={(value) => void updateAppSettings({ fontCacheLimit: value })}
          step={1}
          title="Font cache limit"
          value={settings.fontCacheLimit}
        />
        <NativeGroupedListRow
          description="Delete downloaded images and decoded BlurHash placeholders"
          icon="clearImageCache"
          onPress={() => void handleClearImages()}
          title="Clear image cache"
        />
        <NativeGroupedListRow
          description="Delete downloaded and converted chapter fonts"
          icon="clearFontCache"
          onPress={() => void handleClearReaderFonts()}
          title="Clear reader font cache"
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}
