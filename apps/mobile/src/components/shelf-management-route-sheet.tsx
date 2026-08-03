import BottomSheet, { BottomSheetView } from '@expo/ui/community/bottom-sheet';
import { router } from 'expo-router';
import { useRef, type ReactNode } from 'react';
import { StyleSheet } from 'react-native';

import { colors } from '@/theme/colors';

export function ShelfManagementRouteSheet({ children }: { children: ReactNode }) {
  const dismissed = useRef(false);
  return (
    <BottomSheet
      backgroundStyle={{ backgroundColor: colors.surface as string }}
      enableDynamicSizing
      enablePanDownToClose
      index={0}
      onDismiss={() => {
        if (dismissed.current) return;
        dismissed.current = true;
        router.back();
      }}
    >
      <BottomSheetView style={styles.content}>{children}</BottomSheetView>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({ content: { width: '100%' } });
