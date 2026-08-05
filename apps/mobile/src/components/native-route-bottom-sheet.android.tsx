import BottomSheet, { BottomSheetView } from '@expo/ui/community/bottom-sheet';
import { router } from 'expo-router';
import { useCallback, useContext, useRef } from 'react';
import { StyleSheet } from 'react-native';

import { BookDetailThemeContext } from '@/components/book-detail-theme-provider';
import type { NativeRouteBottomSheetProps } from '@/components/native-route-bottom-sheet';
import { useAppTheme } from '@/theme/app-theme';

export function NativeRouteBottomSheet({
  bookId,
  children,
  snapPoints,
}: NativeRouteBottomSheetProps) {
  const hasDismissed = useRef(false);
  const { colors } = useAppTheme();
  const bookContext = useContext(BookDetailThemeContext);
  // Sheets inside a book detail route use the book palette; everything else
  // (e.g. the community reply composer) falls back to the app theme surface.
  const surface = bookContext && bookId
    ? (bookContext.activeBookId === bookId ? bookContext.theme : bookContext.baseTheme).palette.surface
    : (colors.surface as string);

  const handleDismiss = useCallback(() => {
    if (hasDismissed.current) return;
    hasDismissed.current = true;
    router.back();
  }, []);

  return (
    <BottomSheet
      backgroundStyle={{ backgroundColor: surface }}
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
