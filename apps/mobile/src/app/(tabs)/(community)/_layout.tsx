import Stack from 'expo-router/stack';

import { useSystemScreenStackPreset } from '@/theme/stack-preset';

export default function CommunityStackLayout() {
  const isAndroid = process.env.EXPO_OS === 'android';
  const systemScreenStackPreset = useSystemScreenStackPreset();

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
      <Stack.Screen name="thread/[id]" options={{ headerLargeTitle: false, headerShown: !isAndroid, title: 'Discussion' }} />
      <Stack.Screen
        name="thread/[id]/reply"
        options={{
          ...(isAndroid
            ? { animation: 'none', contentStyle: { backgroundColor: 'transparent' } }
            : { sheetAllowedDetents: 'fitToContents', sheetGrabberVisible: true }),
          headerShown: false,
          presentation: isAndroid ? 'transparentModal' : 'formSheet',
          title: '',
        }}
      />
      <Stack.Screen name="compose" options={{ headerLargeTitle: false, headerShown: !isAndroid, title: 'New post' }} />
      <Stack.Screen name="notifications" options={{ headerLargeTitle: false, headerShown: !isAndroid, title: 'Notifications' }} />
      <Stack.Screen
        name="mine"
        options={{ headerLargeTitle: false, headerShown: !isAndroid, title: 'My Community' }}
      />
      <Stack.Screen
        name="community-rankings"
        options={{ headerLargeTitle: false, headerShown: !isAndroid, title: 'Rankings' }}
      />
    </Stack>
  );
}
