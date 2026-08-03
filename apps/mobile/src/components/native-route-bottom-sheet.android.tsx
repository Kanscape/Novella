import BottomSheet, { BottomSheetView } from '@expo/ui/community/bottom-sheet';
import { router } from 'expo-router';
import { useCallback, useRef } from 'react';
import { StyleSheet } from 'react-native';

import { useBookDetailRouteTheme } from '@/components/book-detail-theme-provider';
import type { NativeRouteBottomSheetProps } from '@/components/native-route-bottom-sheet';

export function NativeRouteBottomSheet({
  bookId,
  children,
  snapPoints,
}: NativeRouteBottomSheetProps) {
  const hasDismissed = useRef(false);
  const { palette } = useBookDetailRouteTheme(bookId, null, null);

  const handleDismiss = useCallback(() => {
    if (hasDismissed.current) return;
    hasDismissed.current = true;
    router.back();
  }, []);

  return (
    <BottomSheet
      backgroundStyle={{ backgroundColor: palette.surface }}
      enableDynamicSizing={!snapPoints}
      enablePanDownToClose
      index={0}
      onDismiss={handleDismiss}
      {...(snapPoints ? { snapPoints } : {})}
    >
      <BottomSheetView style={[styles.content, snapPoints && styles.fill]}>
        {children}
      </BottomSheetView>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({
  content: { width: '100%' },
  fill: { flex: 1 },
});
