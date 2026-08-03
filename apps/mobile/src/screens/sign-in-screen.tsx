import { LinearGradient } from 'expo-linear-gradient';
import { router } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { IconArrowRight } from '@tabler/icons-react-native';

import NovellaLogo from '../../assets/novella-logo.svg';
import {
  AuthFormError,
  AuthFormLayout,
  AuthSubmitButton,
  AuthTextField,
} from '@/components/auth-form-layout';
import { AuthCoverTracks } from '@/components/auth-cover-tracks';
import { AuthFooterLink, PasswordField } from '@/components/auth-fields';
import { useAuthCoverMosaic } from '@/hooks/use-auth-cover-mosaic';
import { authentication } from '@/services/client';
import { useAuthPalette } from '@/theme/auth-theme';

export function AuthWelcomeScreen() {
  const covers = useAuthCoverMosaic();
  const insets = useSafeAreaInsets();
  const { height, width } = useWindowDimensions();
  const palette = useAuthPalette();

  return (
    <View style={[styles.welcomeRoot, { backgroundColor: palette.background }]}>
      <StatusBar style={palette.isDark ? 'light' : 'dark'} />
      <AuthCoverTracks
        books={covers.books}
        height={Math.max(470, Math.min(height * 0.76, 670))}
        palette={palette}
        topInset={insets.top}
        width={width}
      />
      <LinearGradient
        colors={[...palette.welcomeGradient]}
        locations={[0, 0.43, 0.59, 0.72, 1]}
        pointerEvents="none"
        style={StyleSheet.absoluteFill}
      />
      <View style={[styles.welcomeContent, { paddingBottom: Math.max(22, insets.bottom + 12) }]}>
        <NovellaLogo fill={palette.foreground} height={33} width={126} />
        <View style={styles.welcomeCopy}>
          <Text style={[styles.welcomeTitle, { color: palette.foreground }]}>A world in every story.</Text>
          <Text style={[styles.welcomeDescription, { color: palette.secondary }]}>
            Find your next chapter, keep every journey close, and continue exactly where you stopped.
          </Text>
        </View>
        <Pressable
          accessibilityLabel="Start reading"
          accessibilityRole="button"
          onPress={() => router.push('/sign-in/credentials')}
          style={({ pressed }) => [
            styles.heroButton,
            { backgroundColor: palette.accent },
            pressed && styles.buttonPressed,
          ]}
        >
          <Text style={[styles.heroButtonLabel, { color: palette.onAccent }]}>Start reading</Text>
          <IconArrowRight color={palette.onAccent} size={21} strokeWidth={2.1} />
        </Pressable>
      </View>
    </View>
  );
}

export function SignInCredentialsScreen({ initialEmail = '' }: { initialEmail?: string }) {
  const [email, setEmail] = useState(initialEmail);
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const palette = useAuthPalette();

  async function submit() {
    const normalizedEmail = email.trim();
    if (!normalizedEmail || !password) {
      setError('Enter your email and password.');
      return;
    }
    setError(null);
    setIsSubmitting(true);
    try {
      await authentication.signIn(normalizedEmail, password);
      router.replace('/');
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Sign in failed. Try again.');
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <AuthFormLayout
      description="Sign in to sync your shelf, history, and reading progress."
      title="Welcome back"
    >
      <View style={styles.formFields}>
        <AuthTextField
          accessibilityLabel="Email"
          autoCapitalize="none"
          autoComplete="email"
          autoCorrect={false}
          keyboardType="email-address"
          onChangeText={setEmail}
          placeholder="Email"
          returnKeyType="next"
          textContentType="emailAddress"
          value={email}
        />
        <PasswordField
          accessibilityLabel="Password"
          label="Password"
          onChangeText={setPassword}
          onSubmitEditing={() => void submit()}
          value={password}
        />
        <Pressable onPress={() => router.push('/reset-password')} style={styles.trailingLink}>
          <Text style={[styles.linkLabel, { color: palette.accent }]}>Forgot password?</Text>
        </Pressable>
        <AuthFormError message={error} />
        <AuthSubmitButton
          idleLabel="Sign in"
          isSubmitting={isSubmitting}
          onPress={() => void submit()}
          submittingLabel="Signing in…"
        />
        <AuthFooterLink label="New to Novella? Create an account" onPress={() => router.push('/register')} />
      </View>
    </AuthFormLayout>
  );
}

const styles = StyleSheet.create({
  buttonPressed: { opacity: 0.76 },
  formFields: { gap: 13 },
  heroButton: { alignItems: 'center', borderRadius: 28, flexDirection: 'row', gap: 12, justifyContent: 'center', minHeight: 56, paddingHorizontal: 22 },
  heroButtonLabel: { fontSize: 17, fontWeight: '600' },
  linkLabel: { fontSize: 15, fontWeight: '600' },
  trailingLink: { alignSelf: 'flex-end', paddingVertical: 3 },
  welcomeContent: { bottom: 0, gap: 20, left: 0, paddingHorizontal: 22, position: 'absolute', right: 0 },
  welcomeCopy: { gap: 9 },
  welcomeDescription: { fontSize: 16, lineHeight: 23, maxWidth: 360 },
  welcomeRoot: { flex: 1, overflow: 'hidden' },
  welcomeTitle: { fontSize: 34, fontWeight: '700', letterSpacing: -1, lineHeight: 39, maxWidth: 350 },
});
