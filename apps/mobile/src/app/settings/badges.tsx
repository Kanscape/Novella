import { NativeRouteBottomSheet } from '@/components/native-route-bottom-sheet';
import { BookBadgeLegendSheetScreen } from '@/screens/settings/book-badge-legend-sheet-screen';

export default function BookBadgesRoute() {
  return (
    <NativeRouteBottomSheet snapPoints={['50%', '100%']}>
      <BookBadgeLegendSheetScreen />
    </NativeRouteBottomSheet>
  );
}
