import type { ReactNode } from 'react';

export interface NativeRouteBottomSheetProps {
  /** Book context for themed sheets; optional for sheets without a book. */
  bookId?: number;
  children: ReactNode;
  snapPoints?: (number | string)[];
}

export function NativeRouteBottomSheet({ children }: NativeRouteBottomSheetProps) {
  return children;
}
