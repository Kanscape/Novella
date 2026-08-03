import Stack from 'expo-router/stack';

import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function ShelfStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';

  return (
    <Stack screenOptions={systemScreenStackPreset}>
      <Stack.Screen
        name="shelf"
        options={{
          headerLargeTitle: !isAndroid,
          headerShown: !isAndroid,
          title: 'Shelf',
        }}
      />

    </Stack>
  );
}
