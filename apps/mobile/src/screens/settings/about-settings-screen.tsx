import Constants from 'expo-constants';
import * as Linking from 'expo-linking';
import { router } from 'expo-router';

import { NativeGroupedList, NativeGroupedListRow, NativeGroupedListSection } from '@/components/native-grouped-list';
import { NativeValueRow } from '@/components/native-setting-controls';

const repositoryUrl = 'https://github.com/Kanscape/Novella';

function displayVersion(): string {
  const baseVersion = Constants.expoConfig?.version?.trim() ?? '';
  if (!baseVersion) return '版本未知';

  const buildLabel = Constants.expoConfig?.extra?.buildLabel?.trim() ?? '';
  return buildLabel ? `${baseVersion} (${buildLabel})` : baseVersion;
}

export function AboutSettingsScreen() {
  const version = displayVersion();

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
