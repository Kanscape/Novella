import '../global.css';

import { HeroUINativeProvider } from 'heroui-native';
import {
  DarkTheme,
  DefaultTheme,
  ThemeProvider,
} from 'expo-router/react-navigation';
import { Stack } from 'expo-router/stack';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { useEffect, useState } from 'react';
import { ActivityIndicator, StyleSheet, Text, View, useColorScheme } from 'react-native';

import { BookDetailThemeProvider } from '@/components/book-detail-theme-provider';
import { useAuthentication } from '@/hooks/use-authentication';
import { startClient } from '@/services/client';
import { colors } from '@/theme/colors';
import { systemScreenStackPreset } from '@/theme/stack-preset';

export default function RootLayout() {
  const authentication = useAuthentication();
  const colorScheme = useColorScheme();
  const usesComposeBottomSheets = process.env.EXPO_OS === 'android';
  const [hadAuthenticatedSession, setHadAuthenticatedSession] = useState(
    authentication.status === 'authenticated',
  );
  const [startupSettled, setStartupSettled] = useState(false);

  useEffect(() => {
    let mounted = true;
    void startClient().finally(() => {
      if (mounted) setStartupSettled(true);
    });
    return () => {
      mounted = false;
    };
  }, []);

  useEffect(() => {
    if (authentication.status === 'authenticated') setHadAuthenticatedSession(true);
    else if (authentication.status === 'signedOut') setHadAuthenticatedSession(false);
  }, [authentication.status]);

  const hasAuthenticatedSession = authentication.status === 'authenticated'
    ? true
    : authentication.status === 'signedOut'
      ? false
      : hadAuthenticatedSession;
  const navigationTheme = colorScheme === 'dark' ? DarkTheme : DefaultTheme;
  if (!startupSettled) {
    return (
      <GestureHandlerRootView style={styles.gestureRoot}>
        <HeroUINativeProvider config={heroUIConfig}>
          <ThemeProvider value={navigationTheme}>
        <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
        <View style={styles.startupRoot}>
          <ActivityIndicator color={colors.accent as string} size="large" />
          <Text style={styles.startupLabel}>Preparing a secure connection…</Text>
        </View>
          </ThemeProvider>
        </HeroUINativeProvider>
      </GestureHandlerRootView>
    );
  }

  return (
    <GestureHandlerRootView style={styles.gestureRoot}>
      <HeroUINativeProvider config={heroUIConfig}>
        <ThemeProvider value={navigationTheme}>
      <StatusBar style={colorScheme === 'dark' ? 'light' : 'dark'} />
      <BookDetailThemeProvider>
        <Stack screenOptions={systemScreenStackPreset}>
          <Stack.Protected guard={hasAuthenticatedSession}>
          <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
          <Stack.Screen name="settings" options={{ headerShown: false }} />
          <Stack.Screen name="book/[id]" options={{ title: '' }} />
          <Stack.Screen name="book/[id]/comments" options={{ title: 'Comments' }} />
          <Stack.Screen name="recent-updates" options={{ title: 'Recently updated' }} />
          <Stack.Screen name="ranking" options={{ title: 'Rankings' }} />
          <Stack.Screen
            name="shelf/folder"
            options={{ headerShown: true, title: 'Folder' }}
          />
          <Stack.Screen
            name="shelf/manage"
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
          <Stack.Screen
            name="reader/[bookId]/[sortNum]"
            options={{ headerShown: false }}
          />
          <Stack.Screen
            name="reader/[bookId]/footnote"
            options={{
              ...(usesComposeBottomSheets
                ? {
                    animation: 'none',
                    contentStyle: { backgroundColor: 'transparent' },
                  }
                : {
                    sheetAllowedDetents: [0.5, 1],
                    sheetGrabberVisible: true,
                    sheetInitialDetentIndex: 0,
                  }),
              headerShown: false,
              presentation: usesComposeBottomSheets ? 'transparentModal' : 'formSheet',
              title: 'Footnote',
            }}
          />
          <Stack.Screen
            name="reader/[bookId]/chapters"
            options={{
              ...(usesComposeBottomSheets
                ? {
                    animation: 'none',
                    contentStyle: { backgroundColor: 'transparent' },
                  }
                : {
                    sheetAllowedDetents: [0.5, 1],
                    sheetGrabberVisible: true,
                    sheetInitialDetentIndex: 0,
                  }),
              headerShown: false,
              presentation: usesComposeBottomSheets ? 'transparentModal' : 'formSheet',
              title: 'Chapters',
            }}
          />
          </Stack.Protected>
          <Stack.Protected guard={!hasAuthenticatedSession}>
            <Stack.Screen name="sign-in" options={{ headerShown: false }} />
            <Stack.Screen name="sign-in/credentials" options={{ title: 'Sign in' }} />
            <Stack.Screen name="register" options={{ title: 'Create account' }} />
            <Stack.Screen name="register/verify" options={{ title: 'Verify email' }} />
            <Stack.Screen name="reset-password" options={{ title: 'Reset password' }} />
            <Stack.Screen name="reset-password/verify" options={{ title: 'Verify email' }} />
            <Stack.Screen name="reset-password/new-password" options={{ title: 'New password' }} />
          </Stack.Protected>
        </Stack>
      </BookDetailThemeProvider>
        </ThemeProvider>
      </HeroUINativeProvider>
    </GestureHandlerRootView>
  );
}

const heroUIConfig = {
  devInfo: { stylingPrinciples: false },
  toast: 'disabled' as const,
};

const styles = StyleSheet.create({
  gestureRoot: { flex: 1 },
  startupLabel: {
    color: colors.secondaryLabel as string,
    fontSize: 15,
  },
  startupRoot: {
    alignItems: 'center',
    backgroundColor: colors.background as string,
    flex: 1,
    gap: 14,
    justifyContent: 'center',
    padding: 24,
  },
});
