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
import { StyleSheet, View } from 'react-native';

import { BookDetailThemeProvider } from '@/components/book-detail-theme-provider';
import { NativeAlertHost } from '@/components/native-alert-dialog';
import { useAuthentication } from '@/hooks/use-authentication';
import { hasStoredSession, startClient } from '@/services/client';
import { loadAppSettings } from '@/services/settings';
import { AppThemeProvider, useAppTheme } from '@/theme/app-theme';
import { useSystemScreenStackPreset } from '@/theme/stack-preset';

// The session probe is a local SecureStore read (no network). It is kicked off
// at module scope so the route decision (app vs sign-in welcome) is typically
// ready before the first frame paints. The splash shows the logo normally and
// auto-hides; it is never used to cover up a routing transition.

const sessionProbe = Promise.all([hasStoredSession(), loadAppSettings()]);

export default function RootLayout() {
  return (
    <AppThemeProvider>
      <RootLayoutContent />
    </AppThemeProvider>
  );
}

function RootLayoutContent() {
  const authentication = useAuthentication();
  const { colorScheme, colors } = useAppTheme();
  const systemScreenStackPreset = useSystemScreenStackPreset();
  const usesComposeBottomSheets = process.env.EXPO_OS === 'android';
  // False until the local session probe resolves. The probe decides the very
  // first rendered screen, so a logged-in user never passes through the
  // welcome page and a first-install user goes straight to the welcome page.
  const [sessionDecided, setSessionDecided] = useState(false);
  const [hadAuthenticatedSession, setHadAuthenticatedSession] = useState(false);

  useEffect(() => {
    let mounted = true;
    void sessionProbe.then(([stored]) => {
      if (!mounted) return;
      setHadAuthenticatedSession(stored);
      setSessionDecided(true);
    });
    return () => {
      mounted = false;
    };
  }, []);

  // Session init (token refresh + signalR) is a background concern shared by
  // both entry surfaces: the welcome page (first install) and the home page
  // (logged-in, which shows its existing skeletons meanwhile). A failed
  // refresh clears credentials and flips the guard back to the welcome page;
  // manual sign-out does the same.
  useEffect(() => {
    void startClient().catch(() => undefined);
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
  if (!sessionDecided) {
    // A plain themed frame for the sub-frame probe window (local read only,
    // no spinner, no wrong-screen flash); it visually continues the splash.
    return (
      <GestureHandlerRootView style={styles.gestureRoot}>
        <View style={[styles.blankRoot, { backgroundColor: colors.background }]} />
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
          <Stack.Screen name="book/[id]/comments" options={{ headerShown: !usesComposeBottomSheets, title: 'Comments' }} />
          <Stack.Screen name="books" options={{ headerShown: !usesComposeBottomSheets, title: 'All novels' }} />
          <Stack.Screen name="comics" options={{ headerShown: !usesComposeBottomSheets, title: 'All comics' }} />
          <Stack.Screen name="ranking" options={{ headerShown: !usesComposeBottomSheets, title: 'Rankings' }} />
          <Stack.Screen
            name="shelf/folder"
            options={{ headerShown: !usesComposeBottomSheets, title: 'Folder' }}
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
            name="book/[id]/versions"
            options={{
              ...(usesComposeBottomSheets
                ? {
                    animation: 'none',
                    contentStyle: { backgroundColor: 'transparent' },
                  }
                : {
                    sheetAllowedDetents: [0.6, 1],
                    sheetGrabberVisible: true,
                    sheetInitialDetentIndex: 0,
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
          <Stack.Screen
            name="reader/[bookId]/settings"
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
              title: 'Reading',
            }}
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
      <NativeAlertHost />
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
  blankRoot: { flex: 1 },
});
