import {
  DarkTheme,
  DefaultTheme,
  ThemeProvider,
} from 'expo-router/react-navigation';
import { Stack } from 'expo-router/stack';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { useColorScheme } from 'react-native';

import { BookDetailThemeProvider } from '@/components/book-detail-theme-provider';
import { authentication } from '@/services/client';
import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function RootLayout() {
  const colorScheme = useColorScheme();
  const usesComposeBottomSheets = process.env.EXPO_OS === 'android';

  useEffect(() => {
    void authentication.bootstrap();
  }, []);

  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
      <BookDetailThemeProvider>
        <Stack screenOptions={systemScreenStackPreset}>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen name="book/[id]" options={{ title: '' }} />
          <Stack.Screen name="book/[id]/comments" options={{ title: 'Comments' }} />
          <Stack.Screen
            name="book/[id]/comment-compose"
            options={{
              ...(usesComposeBottomSheets
                ? {
                    animation: 'none',
                    contentStyle: { backgroundColor: 'transparent' },
                  }
                : {
                    sheetAllowedDetents: 'fitToContents',
                    sheetGrabberVisible: false,
                  }),
              headerShown: false,
              presentation: usesComposeBottomSheets ? 'transparentModal' : 'formSheet',
              title: '',
            }}
          />
          <Stack.Screen
            name="book/[id]/introduction"
            options={{
              ...(usesComposeBottomSheets
                ? {
                    animation: 'none',
                    contentStyle: { backgroundColor: 'transparent' },
                  }
                : {
                    sheetAllowedDetents: [0.75, 1],
                    sheetGrabberVisible: true,
                    sheetInitialDetentIndex: 0,
                  }),
              headerShown: false,
              presentation: usesComposeBottomSheets ? 'transparentModal' : 'formSheet',
              title: '',
            }}
          />
          <Stack.Screen
            name="book/[id]/tags"
            options={{
              ...(usesComposeBottomSheets
                ? {
                    animation: 'none',
                    contentStyle: { backgroundColor: 'transparent' },
                  }
                : {
                    sheetAllowedDetents: 'fitToContents',
                    sheetGrabberVisible: true,
                  }),
              headerShown: false,
              presentation: usesComposeBottomSheets ? 'transparentModal' : 'formSheet',
              title: '',
            }}
          />
          <Stack.Screen
            name="book/[id]/uploader"
            options={{
              ...(usesComposeBottomSheets
                ? {
                    animation: 'none',
                    contentStyle: { backgroundColor: 'transparent' },
                  }
                : {
                    sheetAllowedDetents: 'fitToContents',
                    sheetGrabberVisible: true,
                  }),
              headerShown: false,
              presentation: usesComposeBottomSheets ? 'transparentModal' : 'formSheet',
              title: '',
            }}
          />
          <Stack.Screen name="sign-in" options={{ title: 'Sign in' }} />
          <Stack.Screen name="register" options={{ title: 'Create account' }} />
          <Stack.Screen name="reset-password" options={{ title: 'Reset password' }} />
        </Stack>
      </BookDetailThemeProvider>
    </ThemeProvider>
  );
}
