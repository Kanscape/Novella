import Stack from 'expo-router/stack';

import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function CommunityStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';

  return (
    <Stack screenOptions={systemScreenStackPreset}>
      <Stack.Screen
        name="community"
        options={{
          headerLargeTitle: !isAndroid,
          headerShown: !isAndroid,
          title: 'Community',
        }}
      />
    </Stack>
  );
}
