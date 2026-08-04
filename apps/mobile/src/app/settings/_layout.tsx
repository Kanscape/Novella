import Stack from 'expo-router/stack';

import { useSystemScreenStackPreset } from '@/theme/stack-preset';

export default function SettingsStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';
  const systemScreenStackPreset = useSystemScreenStackPreset();

  return (
    <Stack screenOptions={{ ...systemScreenStackPreset, headerShown: !isAndroid }}>
      <Stack.Screen
        name="index"
        options={{ headerLargeTitle: !isAndroid, title: 'Settings' }}
      />
      <Stack.Screen name="profile" options={{ title: 'Profile' }} />
      <Stack.Screen name="avatar" options={{ title: 'Avatar' }} />
      <Stack.Screen name="reader" options={{ title: 'Reading' }} />
      <Stack.Screen name="content" options={{ title: 'Content' }} />
      <Stack.Screen name="appearance" options={{ title: 'Appearance' }} />
      <Stack.Screen name="cache" options={{ title: 'Cache' }} />
      <Stack.Screen name="about" options={{ title: 'About Novella' }} />
    </Stack>
  );
}
