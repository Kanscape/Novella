import { router } from 'expo-router';
import { useState } from 'react';
import { StyleSheet, View } from 'react-native';

import {
  AuthFormError,
  AuthFormLayout,
  AuthSubmitButton,
  AuthTextField,
} from '@/components/auth-form-layout';
import { AuthFooterLink } from '@/components/auth-fields';
import { authFlowSession } from '@/services/auth-flow-session';
import { authentication } from '@/services/client';

export default function ResetPasswordRoute() {
  const [email, setEmail] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function continueToVerification() {
    const normalizedEmail = email.trim();
    setError(null);
    setIsSubmitting(true);
    try {
      await authentication.sendResetCode(normalizedEmail);
      authFlowSession.setPasswordReset({ code: '', email: normalizedEmail });
      router.push('/reset-password/verify');
    } catch (submitError) {
      setError(getErrorMessage(submitError));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <AuthFormLayout
      description="Enter your account email and we will send a 4-character verification code."
      title="Reset your password"
    >
      <View style={styles.form}>
        <AuthTextField
          accessibilityLabel="Email"
          autoCapitalize="none"
          autoComplete="email"
          autoCorrect={false}
          keyboardType="email-address"
          onChangeText={setEmail}
          onSubmitEditing={() => void continueToVerification()}
          placeholder="Email"
          returnKeyType="send"
          textContentType="emailAddress"
          value={email}
        />
        <AuthFormError message={error} />
        <AuthSubmitButton
          idleLabel="Send verification code"
          isSubmitting={isSubmitting}
          onPress={() => void continueToVerification()}
          submittingLabel="Sending code…"
        />
        <AuthFooterLink label="Back to sign in" onPress={() => router.replace('/sign-in/credentials')} />
      </View>
    </AuthFormLayout>
  );
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unable to send the verification code.';
}

const styles = StyleSheet.create({ form: { gap: 14 } });
