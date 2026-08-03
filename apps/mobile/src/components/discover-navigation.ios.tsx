import { router, Stack } from 'expo-router';

export function DiscoverNavigation() {
  return (
    <Stack.Toolbar placement="right">
      <Stack.Toolbar.Button
        accessibilityLabel="Profile and settings"
        icon="person.crop.circle"
        onPress={() => router.push('/settings')}
      />
    </Stack.Toolbar>
  );
}
