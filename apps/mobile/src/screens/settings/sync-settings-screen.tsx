import { router } from 'expo-router';

import {
  NativeGroupedList,
  NativeGroupedListRow,
  NativeGroupedListSection,
} from '@/components/native-grouped-list';
import { NativeToggleRow } from '@/components/native-setting-controls';
import { useAuthentication } from '@/hooks/use-authentication';
import { authentication } from '@/services/client';
import { updateAppSettings, useAppSettings } from '@/services/settings';

export function SyncSettingsScreen() {
  const auth = useAuthentication();
  const settings = useAppSettings();
  const isBusy = auth.status === 'refreshing' || auth.status === 'signingOut';

  return (
    <NativeGroupedList
      onBackPress={() => router.back()}
      showBackButton
      testID="sync-settings"
      title="Sync"
    >
      <NativeGroupedListSection title="LightNovelShelf account">
        <NativeGroupedListRow
          description={getAccountDescription(auth.status)}
          disabled={isBusy}
          icon="cloudSync"
          onPress={() => {
            if (auth.status === 'authenticated') {
              void authentication.signOut();
            } else {
              router.push('/sign-in');
            }
          }}
          title={auth.status === 'authenticated' ? 'Sign out' : 'Sign in'}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="App settings">
        <NativeToggleRow
          description="Keep reader and content preferences available to future sync"
          icon="sync"
          onValueChange={(value) => void updateAppSettings({ appSettingsSyncEnabled: value })}
          title="Sync app preferences"
          value={settings.appSettingsSyncEnabled}
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}

function getAccountDescription(status: ReturnType<typeof useAuthentication>['status']): string {
  switch (status) {
    case 'authenticated':
      return 'End the current session on this device';
    case 'refreshing':
      return 'Restoring your session';
    case 'signingOut':
      return 'Signing out';
    default:
      return 'Sign in to use LightNovelShelf services';
  }
}
