import Stack from 'expo-router/stack';

import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function SearchStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';

  return (
    <Stack screenOptions={systemScreenStackPreset}>
      <Stack.Screen
        name="search"
        options={{
          headerLargeTitle: !isAndroid,
          headerShown: !isAndroid,
          title: 'Search',
        }}
      />
    </Stack>
  );
}
