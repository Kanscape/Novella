import Constants from 'expo-constants';
import * as Linking from 'expo-linking';
import { router } from 'expo-router';

import { NativeGroupedList, NativeGroupedListRow, NativeGroupedListSection } from '@/components/native-grouped-list';
import { NativeValueRow } from '@/components/native-setting-controls';

const repositoryUrl = 'https://github.com/Kanscape/Novella';

export function AboutSettingsScreen() {
  const version = Constants.expoConfig?.version ?? '2.0.0';

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="about-settings"
      title="About Novella"
    >
      <NativeGroupedListSection title="Novella">
        <NativeValueRow
          description="Installed app version"
          icon="version"
          title="Version"
          value={version}
        />
        <NativeGroupedListRow
          description="Open the source repository"
          icon="sourceCode"
          onPress={() => void Linking.openURL(repositoryUrl)}
          title="Source code"
        />
        <NativeGroupedListRow
          description="Read release notes on GitHub"
          icon="changelogs"
          onPress={() => void Linking.openURL(`${repositoryUrl}/releases`)}
          title="Changelogs"
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}
