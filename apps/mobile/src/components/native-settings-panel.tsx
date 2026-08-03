import { router } from 'expo-router';

import {
  NativeGroupedList,
  NativeGroupedListRow,
  NativeGroupedListSection,
} from '@/components/native-grouped-list';
import { DisclosureIcon } from '@/components/settings-row-accessories';
import { SettingsRootNavigation } from '@/components/settings-root-navigation';

export function NativeSettingsPanel() {
  const returnToDiscover = () => {
    if (router.canGoBack()) {
      router.back();
      return;
    }
    router.replace('/(tabs)/(discover)');
  };

  return (
    <>
      <NativeGroupedList
        largeTitle
        onBackPress={returnToDiscover}
        showBackButton
        testID="native-settings-panel"
        title="Settings"
      >
        <NativeGroupedListSection title="Account">
          <NativeGroupedListRow
            description="Account information, avatar, growth, and daily check-in"
            icon="account"
            onPress={() => router.push('/settings/profile')}
            title="Profile"
            trailing={<DisclosureIcon />}
          />
        </NativeGroupedListSection>

        <NativeGroupedListSection title="General">
          <NativeGroupedListRow
            description="Typography, layout, and reading behavior"
            icon="reader"
            onPress={() => router.push('/settings/reader')}
            title="Reading"
            trailing={<DisclosureIcon />}
          />
          <NativeGroupedListRow
            description="Home page modules and content filters"
            icon="content"
            onPress={() => router.push('/settings/content')}
            title="Content"
            trailing={<DisclosureIcon />}
          />
          <NativeGroupedListRow
            description="Theme, colors, and display style"
            icon="appearance"
            onPress={() => router.push('/settings/appearance')}
            title="Appearance"
            trailing={<DisclosureIcon />}
          />
        </NativeGroupedListSection>

        <NativeGroupedListSection title="Data">
          <NativeGroupedListRow
            description="Cache policy and local storage"
            icon="cache"
            onPress={() => router.push('/settings/cache')}
            title="Cache"
            trailing={<DisclosureIcon />}
          />
        </NativeGroupedListSection>

        <NativeGroupedListSection title="About">
          <NativeGroupedListRow
            description="Version, source code, and project links"
            icon="info"
            onPress={() => router.push('/settings/about')}
            title="About Novella"
            trailing={<DisclosureIcon />}
          />
        </NativeGroupedListSection>
      </NativeGroupedList>
      <SettingsRootNavigation />
    </>
  );
}
