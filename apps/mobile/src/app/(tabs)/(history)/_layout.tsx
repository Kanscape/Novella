import Stack from 'expo-router/stack';

import { useSystemScreenStackPreset } from '@/theme/stack-preset';

export default function HistoryStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';
  const systemScreenStackPreset = useSystemScreenStackPreset();

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
