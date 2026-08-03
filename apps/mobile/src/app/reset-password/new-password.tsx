import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import {
  AuthFormError,
  AuthFormLayout,
  AuthSubmitButton,
} from '@/components/auth-form-layout';
import { PasswordField } from '@/components/auth-fields';
import { authFlowSession } from '@/services/auth-flow-session';
import { authentication } from '@/services/client';

export default function ResetPasswordNewPasswordRoute() {
  const [draft] = useState(() => authFlowSession.getPasswordReset());
  const [password, setPassword] = useState('');
  const [passwordConfirmation, setPasswordConfirmation] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!draft?.code) router.replace('/reset-password');
  }, [draft]);

  async function submit() {
    if (!draft?.code) return;
    setError(null);
    setIsSubmitting(true);
    try {
      await authentication.resetPassword({
        code: draft.code,
        email: draft.email,
        password,
        passwordConfirmation,
      });
      authFlowSession.clearPasswordReset();
      router.replace({ pathname: '/sign-in/credentials', params: { email: draft.email } });
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'Unable to reset your password.');
    } finally {
      setIsSubmitting(false);
    }
  }

  if (!draft?.code) return null;
  return (
    <AuthFormLayout
      description="Choose a new password with at least 8 characters."
      title="Choose a new password"
    >
      <View style={styles.form}>
        <PasswordField accessibilityLabel="New password" label="New password" onChangeText={setPassword} value={password} />
        <PasswordField accessibilityLabel="Confirm new password" label="Confirm new password" onChangeText={setPasswordConfirmation} value={passwordConfirmation} />
        <AuthFormError message={error} />
        <AuthSubmitButton
          idleLabel="Reset password"
          isSubmitting={isSubmitting}
          onPress={() => void submit()}
          submittingLabel="Resetting password…"
        />
      </View>
    </AuthFormLayout>
  );
}

const styles = StyleSheet.create({ form: { gap: 14 } });
