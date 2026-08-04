import { Host, LazyColumn } from '@expo/ui/jetpack-compose';
import { fillMaxWidth } from '@expo/ui/jetpack-compose/modifiers';
import { useLocalSearchParams } from 'expo-router';
import { StyleSheet } from 'react-native';

import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { ReaderSettingsContent } from '@/screens/settings/reader-settings-screen';
import { useAppColorScheme, useAppTheme } from '@/theme/app-theme';

export function ReaderSettingsSheetScreen() {
  const { bookId: rawBookId } = useLocalSearchParams<{ bookId?: string }>();
  const bookId = Number(rawBookId);
  const colorScheme = useAppColorScheme();
  const { colors } = useAppTheme();

  return (
    <NativeRouteBottomSheet bookId={bookId} snapPoints={['50%', '100%']}>
      <Host colorScheme={colorScheme} seedColor={colors.accent} style={styles.host}>
        <LazyColumn
          contentPadding={{ start: 16, top: 16, end: 16, bottom: 112 }}
          modifiers={[fillMaxWidth()]}
          verticalArrangement={{ spacedBy: 20 }}
        >
          <ReaderSettingsContent />
        </LazyColumn>
      </Host>
    </NativeRouteBottomSheet>
  );
}

const styles = StyleSheet.create({
  host: { flex: 1, width: '100%' },
});
