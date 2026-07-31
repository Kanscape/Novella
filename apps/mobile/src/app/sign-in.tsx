import { Stack, router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { IconEye, IconEyeOff } from '@tabler/icons-react-native';

import { authentication } from '@/services/client';
import { colors } from '@/theme/colors';

export default function SignInRoute() {
  const { email: emailParam } = useLocalSearchParams<{ email?: string }>();
  const [email, setEmail] = useState(typeof emailParam === 'string' ? emailParam : '');
  const [password, setPassword] = useState('');
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

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
      setError(getSignInErrorMessage(submitError));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={styles.root}
    >
      <Stack.Screen options={{ title: 'Sign in' }} />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={styles.content}
        keyboardShouldPersistTaps="handled"
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.header}>
          <Text style={styles.title}>Sign in to Novella</Text>
          <Text style={styles.description}>
            Sign in to open book details, your shelf, history, and reading progress.
          </Text>
        </View>

        <View style={styles.form}>
          <TextInput
            accessibilityLabel="Email"
            autoCapitalize="none"
            autoComplete="email"
            autoCorrect={false}
            keyboardType="email-address"
            placeholder="Email"
            placeholderTextColor={colors.secondaryLabel as string}
            returnKeyType="next"
            style={styles.input}
            textContentType="emailAddress"
            value={email}
            onChangeText={setEmail}
          />
          <View style={styles.passwordRow}>
            <TextInput
              accessibilityLabel="Password"
              autoCapitalize="none"
              autoComplete="password"
              autoCorrect={false}
              placeholder="Password"
              placeholderTextColor={colors.secondaryLabel as string}
              returnKeyType="done"
              secureTextEntry={!passwordVisible}
              style={styles.passwordInput}
              textContentType="password"
              value={password}
              onChangeText={setPassword}
              onSubmitEditing={() => void submit()}
            />
            <Pressable
              accessibilityLabel={passwordVisible ? 'Hide password' : 'Show password'}
              accessibilityRole="button"
              onPress={() => setPasswordVisible((value) => !value)}
              style={({ pressed }) => [styles.passwordToggle, pressed && styles.pressed]}
            >
              {passwordVisible ? (
                <IconEyeOff color={colors.secondaryLabel as string} size={20} strokeWidth={2} />
              ) : (
                <IconEye color={colors.secondaryLabel as string} size={20} strokeWidth={2} />
              )}
            </Pressable>
          </View>

          <View style={styles.authLinks}>
            <Pressable
              accessibilityLabel="Create an account"
              accessibilityRole="button"
              onPress={() => router.push('/register')}
              style={({ pressed }) => [styles.linkButton, pressed && styles.pressed]}
            >
              <Text style={styles.linkLabel}>Create an account</Text>
            </Pressable>
            <Pressable
              accessibilityLabel="Forgot password"
              accessibilityRole="button"
              onPress={() => router.push('/reset-password')}
              style={({ pressed }) => [styles.linkButton, pressed && styles.pressed]}
            >
              <Text style={styles.linkLabel}>Forgot password?</Text>
            </Pressable>
          </View>

          {error ? <Text style={styles.error}>{error}</Text> : null}

          <Pressable
            accessibilityLabel={isSubmitting ? 'Signing in' : 'Sign in'}
            accessibilityRole="button"
            disabled={isSubmitting}
            onPress={() => void submit()}
            style={({ pressed }) => [styles.submitButton, pressed && styles.pressed, isSubmitting && styles.disabled]}
          >
            {isSubmitting ? <ActivityIndicator color="#FFFFFF" /> : null}
            <Text style={styles.submitLabel}>{isSubmitting ? 'Signing in...' : 'Sign in'}</Text>
          </Pressable>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function getSignInErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Sign in failed. Try again.';
}

const styles = StyleSheet.create({
  content: { gap: 24, padding: 20, paddingBottom: 48 },
  authLinks: { flexDirection: 'row', justifyContent: 'space-between' },
  description: { color: colors.secondaryLabel as string, fontSize: 16, lineHeight: 23 },
  disabled: { opacity: 0.55 },
  error: { color: '#FF526D', fontSize: 14, lineHeight: 20 },
  form: { gap: 12 },
  header: { gap: 8 },
  input: { backgroundColor: colors.card as string, borderColor: colors.separator as string, borderRadius: 12, borderWidth: 0.5, color: colors.label as string, fontSize: 16, height: 50, paddingHorizontal: 14 },
  linkButton: { paddingVertical: 4 },
  linkLabel: { color: colors.accent as string, fontSize: 14, fontWeight: '600' },
  passwordInput: { color: colors.label as string, flex: 1, fontSize: 16, height: 49, paddingHorizontal: 14 },
  passwordRow: { alignItems: 'center', backgroundColor: colors.card as string, borderColor: colors.separator as string, borderRadius: 12, borderWidth: 0.5, flexDirection: 'row' },
  passwordToggle: { alignItems: 'center', height: 49, justifyContent: 'center', width: 48 },
  pressed: { opacity: 0.7 },
  root: { backgroundColor: colors.background as string, flex: 1 },
  submitButton: { alignItems: 'center', backgroundColor: colors.accent as string, borderRadius: 12, flexDirection: 'row', gap: 8, justifyContent: 'center', minHeight: 50, paddingHorizontal: 18 },
  submitLabel: { color: '#FFFFFF', fontSize: 16, fontWeight: '700' },
  title: { color: colors.label as string, fontSize: 30, fontWeight: '800', lineHeight: 36 },
});
