import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import { IconChevronLeft, IconChevronRight, IconRefresh } from '@tabler/icons-react-native';

import { colors } from '@/theme/colors';

export function ReaderChapterBar({ current, total, bottomInset, onPrevious, onNext }: {
  current: number;
  total: number;
  bottomInset: number;
  onPrevious: (() => void) | null;
  onNext: (() => void) | null;
}) {
  return (
    <View style={[styles.chapterBar, { paddingBottom: bottomInset + 10 }]}>
      <View style={styles.side}>
        <Pressable accessibilityLabel="Previous chapter" disabled={onPrevious === null} onPress={onPrevious ?? undefined} style={[styles.chapterButton, onPrevious === null && styles.disabled]}>
          <IconChevronLeft color={onPrevious ? colors.accent as string : colors.secondaryLabel as string} size={20} />
          <Text style={styles.chapterText}>Previous</Text>
        </Pressable>
      </View>
      <Text style={styles.chapterCount}>{total > 0 ? `${current} / ${total}` : ''}</Text>
      <View style={[styles.side, styles.sideEnd]}>
        <Pressable accessibilityLabel="Next chapter" disabled={onNext === null} onPress={onNext ?? undefined} style={[styles.chapterButton, onNext === null && styles.disabled]}>
          <Text style={styles.chapterText}>Next</Text>
          <IconChevronRight color={onNext ? colors.accent as string : colors.secondaryLabel as string} size={20} />
        </Pressable>
      </View>
    </View>
  );
}

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
  chapterBar: { alignItems: 'center', backgroundColor: colors.surface as string, borderTopColor: colors.separator as string, borderTopWidth: StyleSheet.hairlineWidth, flexDirection: 'row', paddingHorizontal: 16, paddingTop: 8 },
  // Symmetric flex sides keep the counter perfectly centered horizontally
  // and vertically aligned with the buttons, while the buttons hug the
  // outer edges (Previous left, Next right).
  side: { flex: 1, flexDirection: 'row' },
  sideEnd: { justifyContent: 'flex-end' },
  chapterButton: { alignItems: 'center', flexDirection: 'row', gap: 4, paddingVertical: 8 },
  chapterText: { color: colors.accent as string, fontSize: 14, fontWeight: '600' },
  chapterCount: { color: colors.secondaryLabel as string, fontSize: 13 },
  disabled: { opacity: 0.4 },
  centered: { alignItems: 'center', flex: 1, justifyContent: 'center', padding: 24 },
  errorText: { color: colors.secondaryLabel as string, fontSize: 15, marginBottom: 14, textAlign: 'center' },
  retry: { alignItems: 'center', flexDirection: 'row', gap: 6, padding: 10 },
  retryText: { color: colors.accent as string, fontSize: 15, fontWeight: '600' },
  preparationLabel: { color: colors.label as string, fontSize: 15, fontWeight: '600', marginTop: 14 },
  preparationProgress: { color: colors.secondaryLabel as string, fontSize: 13, fontVariant: ['tabular-nums'], marginTop: 4 },
});
