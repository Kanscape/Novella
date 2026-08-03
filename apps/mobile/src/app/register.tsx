import { router } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import {
  AuthFormError,
  AuthFormLayout,
  AuthSubmitButton,
  AuthTextField,
} from '@/components/auth-form-layout';
import { AuthFooterLink, PasswordField } from '@/components/auth-fields';
import { authFlowSession } from '@/services/auth-flow-session';
import { authentication } from '@/services/client';

export default function RegisterRoute() {
  const [userName, setUserName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [passwordConfirmation, setPasswordConfirmation] = useState('');
  const [inviteCode, setInviteCode] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function continueToVerification() {
    const normalizedEmail = email.trim();
    if (!userName.trim()) {
      setError('Enter a username.');
      return;
    }
    if (password.length < 8) {
      setError('Password must be at least 8 characters.');
      return;
    }
    if (password !== passwordConfirmation) {
      setError('Passwords do not match.');
      return;
    }
    setError(null);
    setIsSubmitting(true);
    try {
      await authentication.sendRegisterCode(normalizedEmail);
      authFlowSession.setRegistration({
        email: normalizedEmail,
        inviteCode,
        password,
        passwordConfirmation,
        userName,
      });
      router.push('/register/verify');
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <AuthFormLayout
      description="Set up your account details. We will send a 4-character verification code to your email."
      title="Create your account"
    >
      <View style={styles.form}>
        <AuthTextField
          accessibilityLabel="Username"
          autoCapitalize="words"
          autoCorrect={false}
          onChangeText={setUserName}
          placeholder="Username"
          returnKeyType="next"
          textContentType="nickname"
          value={userName}
        />
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
        <PasswordField accessibilityLabel="Password" label="Password" onChangeText={setPassword} value={password} />
        <PasswordField accessibilityLabel="Confirm password" label="Confirm password" onChangeText={setPasswordConfirmation} value={passwordConfirmation} />
        <AuthTextField
          accessibilityLabel="Invite code"
          autoCapitalize="none"
          autoCorrect={false}
          onChangeText={setInviteCode}
          placeholder="Invite code (optional)"
          returnKeyType="done"
          value={inviteCode}
        />
        <AuthFormError message={error} />
        <AuthSubmitButton
          idleLabel="Continue"
          isSubmitting={isSubmitting}
          onPress={() => void continueToVerification()}
          submittingLabel="Sending code…"
        />
        <AuthFooterLink
          label="Already have an account? Sign in"
          onPress={() => router.replace('/sign-in/credentials')}
        />
      </View>
    </AuthFormLayout>
  );
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unable to send the verification code.';
}

const styles = StyleSheet.create({ form: { gap: 14 } });
