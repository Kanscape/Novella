import type { ReactNode } from 'react';

export interface NativeRouteBottomSheetProps {
  bookId: number;
  children: ReactNode;
  snapPoints?: (number | string)[];
}

export function NativeRouteBottomSheet({ children }: NativeRouteBottomSheetProps) {
  return children;
}
