import { router } from 'expo-router';

import {
  NativeGroupedList,
  NativeGroupedListRow,
  NativeGroupedListSection,
} from '@/components/native-grouped-list';
import { DisclosureIcon } from '@/components/settings-row-accessories';
import { useAuthentication } from '@/hooks/use-authentication';
import { authentication } from '@/services/client';

export function NativeSettingsPanel() {
  const auth = useAuthentication();
  const isBusy = auth.status === 'refreshing' || auth.status === 'signingOut';
  const isAuthenticated = auth.status === 'authenticated';
  const accountAction = isBusy
    ? undefined
    : isAuthenticated
      ? () => void authentication.signOut().catch(() => undefined)
      : () => router.push('/sign-in');

  return (
    <NativeGroupedList largeTitle testID="native-settings-panel" title="Settings">
      <NativeGroupedListSection title="Account">
        <NativeGroupedListRow
          description={auth.error ?? getAccountActionLabel(auth.status)}
          disabled={isBusy}
          icon="account"
          {...(accountAction ? { onPress: accountAction } : {})}
          title={getAccountLabel(auth.status)}
          trailing={<DisclosureIcon />}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="General">
        <NativeGroupedListRow
          description="Typography, layout, and reading behavior"
          icon="reader"
          onPress={() => router.push('/reader')}
          title="Reading"
          trailing={<DisclosureIcon />}
        />
        <NativeGroupedListRow
          description="Home page modules and content filters"
          icon="content"
          onPress={() => router.push('/content')}
          title="Content"
          trailing={<DisclosureIcon />}
        />
        <NativeGroupedListRow
          description="Theme, colors, and display style"
          icon="appearance"
          onPress={() => router.push('/appearance')}
          title="Appearance"
          trailing={<DisclosureIcon />}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="Data">
        <NativeGroupedListRow
          description="Cache policy and local storage"
          icon="cache"
          onPress={() => router.push('/cache')}
          title="Cache"
          trailing={<DisclosureIcon />}
        />
      </NativeGroupedListSection>

      <NativeGroupedListSection title="About">
        <NativeGroupedListRow
          description="Version, source code, and project links"
          icon="info"
          onPress={() => router.push('/about')}
          title="About Novella"
          trailing={<DisclosureIcon />}
        />
      </NativeGroupedListSection>
    </NativeGroupedList>
  );
}

function getAccountLabel(status: ReturnType<typeof useAuthentication>['status']): string {
  switch (status) {
    case 'authenticated':
      return 'Signed in';
    case 'refreshing':
      return 'Restoring session...';
    case 'signingIn':
      return 'Signing in...';
    case 'signingOut':
      return 'Signing out...';
    case 'signedOut':
      return 'Not signed in';
    default:
      return 'Checking account...';
  }
}

function getAccountActionLabel(status: ReturnType<typeof useAuthentication>['status']): string {
  switch (status) {
    case 'authenticated':
      return 'Sign out from this device';
    case 'refreshing':
      return 'Please wait while the session is restored';
    case 'signingIn':
      return 'Sign-in is in progress';
    case 'signingOut':
      return 'Sign-out is in progress';
    default:
      return 'Use your LightNovelShelf account';
  }
}
