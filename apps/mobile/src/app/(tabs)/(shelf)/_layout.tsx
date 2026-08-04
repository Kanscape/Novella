import Stack from 'expo-router/stack';

import { useSystemScreenStackPreset } from '@/theme/stack-preset';

export default function ShelfStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';
  const systemScreenStackPreset = useSystemScreenStackPreset();

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
