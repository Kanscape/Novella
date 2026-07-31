import { IconEye, IconEyeOff, IconSend } from '@tabler/icons-react-native';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { colors } from '@/theme/colors';

export function PasswordField({
  accessibilityLabel,
  label,
  onChangeText,
  onSubmitEditing,
  value,
}: {
  accessibilityLabel: string;
  label: string;
  onChangeText: (value: string) => void;
  onSubmitEditing?: () => void;
  value: string;
}) {
  const [visible, setVisible] = useState(false);

  return (
    <View style={styles.passwordRow}>
      <TextInput
        accessibilityLabel={accessibilityLabel}
        autoCapitalize="none"
        autoCorrect={false}
        placeholder={label}
        placeholderTextColor={colors.secondaryLabel as string}
        secureTextEntry={!visible}
        style={styles.passwordInput}
        textContentType={label === 'Password' ? 'password' : 'newPassword'}
        value={value}
        onChangeText={onChangeText}
        onSubmitEditing={onSubmitEditing}
      />
      <Pressable
        accessibilityLabel={visible ? `Hide ${label.toLowerCase()}` : `Show ${label.toLowerCase()}`}
        accessibilityRole="button"
        onPress={() => setVisible((current) => !current)}
        style={({ pressed }) => [styles.passwordToggle, pressed && styles.pressed]}
      >
        {visible ? (
          <IconEyeOff color={colors.secondaryLabel as string} size={20} strokeWidth={2} />
        ) : (
          <IconEye color={colors.secondaryLabel as string} size={20} strokeWidth={2} />
        )}
      </Pressable>
    </View>
  );
}

export function VerificationCodeField({
  cooldown,
  isSending,
  onChangeText,
  onSend,
  value,
}: {
  cooldown: number;
  isSending: boolean;
  onChangeText: (value: string) => void;
  onSend: () => void;
  value: string;
}) {
  const canSend = !isSending && cooldown === 0;
  return (
    <View style={styles.codeRow}>
      <TextInput
        accessibilityLabel="Verification code"
        autoCapitalize="none"
        autoCorrect={false}
        keyboardType="number-pad"
        placeholder="Verification code"
        placeholderTextColor={colors.secondaryLabel as string}
        style={styles.codeInput}
        value={value}
        onChangeText={onChangeText}
      />
      <Pressable
        accessibilityLabel={isSending ? 'Sending verification code' : 'Send verification code'}
        accessibilityRole="button"
        disabled={!canSend}
        onPress={onSend}
        style={({ pressed }) => [styles.sendButton, !canSend && styles.disabled, pressed && styles.pressed]}
      >
        {isSending ? null : <IconSend color={canSend ? '#FFFFFF' : colors.secondaryLabel as string} size={16} strokeWidth={2} />}
        <Text style={[styles.sendLabel, !canSend && styles.disabledLabel]}>
          {isSending ? 'Sending...' : cooldown > 0 ? `${cooldown}s` : 'Send code'}
        </Text>
      </Pressable>
    </View>
  );
}

export function AuthFooterLink({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      onPress={onPress}
      style={({ pressed }) => [styles.footerLink, pressed && styles.pressed]}
    >
      <Text style={styles.footerLinkLabel}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  codeInput: { color: colors.label as string, flex: 1, fontSize: 16, height: 49, paddingHorizontal: 14 },
  codeRow: { alignItems: 'center', backgroundColor: colors.card as string, borderColor: colors.separator as string, borderRadius: 12, borderWidth: 0.5, flexDirection: 'row' },
  disabled: { opacity: 0.55 },
  disabledLabel: { color: colors.secondaryLabel as string },
  footerLink: { paddingVertical: 4 },
  footerLinkLabel: { color: colors.accent as string, fontSize: 14, fontWeight: '600' },
  passwordInput: { color: colors.label as string, flex: 1, fontSize: 16, height: 49, paddingHorizontal: 14 },
  passwordRow: { alignItems: 'center', backgroundColor: colors.card as string, borderColor: colors.separator as string, borderRadius: 12, borderWidth: 0.5, flexDirection: 'row' },
  passwordToggle: { alignItems: 'center', height: 49, justifyContent: 'center', width: 48 },
  pressed: { opacity: 0.7 },
  sendButton: { alignItems: 'center', backgroundColor: colors.accent as string, borderRadius: 9, flexDirection: 'row', gap: 5, justifyContent: 'center', marginRight: 6, minHeight: 38, paddingHorizontal: 10 },
  sendLabel: { color: '#FFFFFF', fontSize: 13, fontWeight: '700' },
});
