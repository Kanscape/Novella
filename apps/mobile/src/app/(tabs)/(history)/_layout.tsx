import Stack from 'expo-router/stack';

import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function HistoryStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';

  return (
    <Stack screenOptions={systemScreenStackPreset}>
      <Stack.Screen
        name="history"
        options={{
          headerLargeTitle: !isAndroid,
          headerShown: !isAndroid,
          title: 'History',
        }}
      />
    </Stack>
  );
}
