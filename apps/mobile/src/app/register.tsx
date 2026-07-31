import { Stack, router } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { AuthFooterLink, PasswordField, VerificationCodeField } from '@/components/auth-fields';
import { authentication } from '@/services/client';
import { colors } from '@/theme/colors';

export default function RegisterRoute() {
  const [userName, setUserName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [passwordConfirmation, setPasswordConfirmation] = useState('');
  const [code, setCode] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [cooldown, setCooldown] = useState(0);
  const [isSending, setIsSending] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (cooldown === 0) return undefined;
    const timer = setInterval(() => setCooldown((value) => Math.max(0, value - 1)), 1_000);
    return () => clearInterval(timer);
  }, [cooldown]);

  async function sendCode() {
    setError(null);
    setIsSending(true);
    try {
      await authentication.sendRegisterCode(email);
      setCooldown(60);
    } catch (sendError) {
      setError(getErrorMessage(sendError));
    } finally {
      setIsSending(false);
    }
  }

  async function submit() {
    setError(null);
    setIsSubmitting(true);
    try {
      await authentication.register({
        userName,
        email,
        password,
        passwordConfirmation,
        code,
        inviteCode,
      });
      router.replace('/');
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={styles.root}>
      <Stack.Screen options={{ title: 'Create account' }} />
      <ScrollView contentInsetAdjustmentBehavior="automatic" contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled" showsVerticalScrollIndicator={false}>
        <View style={styles.header}>
          <Text style={styles.title}>Create your Novella account</Text>
          <Text style={styles.description}>Register with LightNovelShelf to sync your shelf, history, and reading progress.</Text>
        </View>

        <View style={styles.form}>
          <TextInput
            accessibilityLabel="Username"
            autoCapitalize="words"
            autoCorrect={false}
            placeholder="Username"
            placeholderTextColor={colors.secondaryLabel as string}
            returnKeyType="next"
            style={styles.input}
            textContentType="nickname"
            value={userName}
            onChangeText={setUserName}
          />
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
          <PasswordField accessibilityLabel="Password" label="Password" value={password} onChangeText={setPassword} />
          <PasswordField accessibilityLabel="Confirm password" label="Confirm password" value={passwordConfirmation} onChangeText={setPasswordConfirmation} />
          <VerificationCodeField cooldown={cooldown} isSending={isSending} value={code} onChangeText={setCode} onSend={() => void sendCode()} />
          <TextInput
            accessibilityLabel="Invite code"
            autoCapitalize="none"
            autoCorrect={false}
            placeholder="Invite code (optional)"
            placeholderTextColor={colors.secondaryLabel as string}
            style={styles.input}
            value={inviteCode}
            onChangeText={setInviteCode}
          />

          {error ? <Text style={styles.error}>{error}</Text> : null}

          <Pressable
            accessibilityLabel={isSubmitting ? 'Creating account' : 'Create account'}
            accessibilityRole="button"
            disabled={isSubmitting}
            onPress={() => void submit()}
            style={({ pressed }) => [styles.submitButton, pressed && styles.pressed, isSubmitting && styles.disabled]}
          >
            <Text style={styles.submitLabel}>{isSubmitting ? 'Creating account...' : 'Create account'}</Text>
          </Pressable>

          <View style={styles.footer}>
            <AuthFooterLink label="Already have an account? Sign in" onPress={() => router.replace('/sign-in')} />
            <AuthFooterLink label="Forgot password?" onPress={() => router.push('/reset-password')} />
          </View>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unable to create your account.';
}

const styles = StyleSheet.create({
  content: { gap: 24, padding: 20, paddingBottom: 48 },
  description: { color: colors.secondaryLabel as string, fontSize: 16, lineHeight: 23 },
  disabled: { opacity: 0.55 },
  error: { color: '#FF526D', fontSize: 14, lineHeight: 20 },
  footer: { flexDirection: 'row', justifyContent: 'space-between' },
  form: { gap: 12 },
  header: { gap: 8 },
  input: { backgroundColor: colors.card as string, borderColor: colors.separator as string, borderRadius: 12, borderWidth: 0.5, color: colors.label as string, fontSize: 16, height: 50, paddingHorizontal: 14 },
  pressed: { opacity: 0.7 },
  root: { backgroundColor: colors.background as string, flex: 1 },
  submitButton: { alignItems: 'center', backgroundColor: colors.accent as string, borderRadius: 12, justifyContent: 'center', minHeight: 50, paddingHorizontal: 18 },
  submitLabel: { color: '#FFFFFF', fontSize: 16, fontWeight: '700' },
  title: { color: colors.label as string, fontSize: 30, fontWeight: '800', lineHeight: 36 },
});
