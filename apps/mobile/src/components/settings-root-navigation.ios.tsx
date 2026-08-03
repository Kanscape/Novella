import { router, Stack } from 'expo-router';

export function SettingsRootNavigation() {
  return (
    <Stack.Toolbar placement="left">
      <Stack.Toolbar.Button
        accessibilityLabel="Back to Discover"
        icon="chevron.left"
        onPress={returnToDiscover}
      />
    </Stack.Toolbar>
  );
}

function returnToDiscover() {
  if (router.canGoBack()) {
    router.back();
    return;
  }
  router.replace('/(tabs)/(discover)');
}
