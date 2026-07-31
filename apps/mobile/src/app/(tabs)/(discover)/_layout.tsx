import Stack from 'expo-router/stack';

import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function DiscoverStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';

  return (
    <Stack screenOptions={systemScreenStackPreset}>
      <Stack.Screen
        name="index"
        options={{
          headerLargeTitle: !isAndroid,
          headerShown: !isAndroid,
          title: 'Discover',
        }}
      />
    </Stack>
  );
}
