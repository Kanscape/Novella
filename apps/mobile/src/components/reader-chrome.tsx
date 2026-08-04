import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { IconRefresh } from '@tabler/icons-react-native';

import { colors } from '@/theme/colors';

export function ReaderPreparationState({ label, progress }: { label: string; progress?: string }) {
  return (
    <View style={styles.centered}>
      <ActivityIndicator color={colors.accent as string} />
      <Text selectable style={styles.preparationLabel}>{label}</Text>
      {progress ? <Text selectable style={styles.preparationProgress}>{progress}</Text> : null}
    </View>
  );
}

export function ReaderErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <View style={styles.centered}>
      <Text style={styles.errorText}>{message}</Text>
      <Pressable accessibilityLabel="Retry reader" onPress={onRetry} style={styles.retry}>
        <IconRefresh color={colors.accent as string} size={18} />
        <Text style={styles.retryText}>Try again</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  centered: { alignItems: 'center', flex: 1, justifyContent: 'center', padding: 24 },
  errorText: { color: colors.secondaryLabel as string, fontSize: 15, marginBottom: 14, textAlign: 'center' },
  retry: { alignItems: 'center', flexDirection: 'row', gap: 6, padding: 10 },
  retryText: { color: colors.accent as string, fontSize: 15, fontWeight: '600' },
  preparationLabel: { color: colors.label as string, fontSize: 15, fontWeight: '600', marginTop: 14 },
  preparationProgress: { color: colors.secondaryLabel as string, fontSize: 13, fontVariant: ['tabular-nums'], marginTop: 4 },
});
