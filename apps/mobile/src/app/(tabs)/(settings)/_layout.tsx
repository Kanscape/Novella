import Stack from 'expo-router/stack';

import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function SettingsStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';

  return (
    <Stack screenOptions={{ ...systemScreenStackPreset, headerShown: !isAndroid }}>
      <Stack.Screen
        name="settings"
        options={{ headerLargeTitle: !isAndroid, title: 'Settings' }}
      />
      <Stack.Screen name="reader" options={{ title: 'Reading' }} />
      <Stack.Screen name="content" options={{ title: 'Content' }} />
      <Stack.Screen name="appearance" options={{ title: 'Appearance' }} />
      <Stack.Screen name="cache" options={{ title: 'Cache' }} />
      <Stack.Screen name="about" options={{ title: 'About Novella' }} />
    </Stack>
  );
}
