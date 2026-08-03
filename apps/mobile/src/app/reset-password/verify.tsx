import { router } from 'expo-router';
import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

import {
  AuthFormError,
  AuthFormLayout,
  AuthSubmitButton,
} from '@/components/auth-form-layout';
import { VerificationCodeField } from '@/components/auth-fields';
import { authFlowSession } from '@/services/auth-flow-session';
import { authentication } from '@/services/client';

export default function ResetPasswordVerifyRoute() {
  const [draft] = useState(() => authFlowSession.getPasswordReset());
  const [code, setCode] = useState('');
  const [cooldown, setCooldown] = useState(60);
  const [isSending, setIsSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!draft) router.replace('/reset-password');
  }, [draft]);

  useEffect(() => {
    if (cooldown === 0) return undefined;
    const timer = setInterval(() => setCooldown((value) => Math.max(0, value - 1)), 1_000);
    return () => clearInterval(timer);
  }, [cooldown]);

  async function resend() {
    if (!draft) return;
    setError(null);
    setIsSending(true);
    try {
      await authentication.sendResetCode(draft.email);
      setCooldown(60);
    } catch (sendError) {
      setError(getErrorMessage(sendError));
    } finally {
      setIsSending(false);
    }
  }

  function continueToPassword() {
    if (!draft) return;
    if (code.length !== 4) {
      setError('Enter the 4-character verification code.');
      return;
    }
    authFlowSession.setPasswordReset({ ...draft, code });
    router.push('/reset-password/new-password');
  }

  if (!draft) return null;
  return (
    <AuthFormLayout
      description={`Enter the 4-character code sent to ${draft.email}.`}
      title="Check your email"
    >
      <View style={styles.form}>
        <VerificationCodeField
          cooldown={cooldown}
          error={Boolean(error && code.length !== 4)}
          isSending={isSending}
          onChangeText={setCode}
          onSend={() => void resend()}
          value={code}
        />
        <AuthFormError message={error} />
        <AuthSubmitButton
          idleLabel="Continue"
          isSubmitting={false}
          onPress={continueToPassword}
          submittingLabel="Continue"
        />
      </View>
    </AuthFormLayout>
  );
}

function getErrorMessage(error: unknown): string {
  return error instanceof Error ? error.message : 'Unable to send the verification code.';
}

const styles = StyleSheet.create({ form: { gap: 18 } });
