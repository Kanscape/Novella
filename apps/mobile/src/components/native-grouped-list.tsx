import type { PropsWithChildren, ReactNode } from 'react';

import {
  NativeGroupedListPlatform,
  NativeGroupedListRowPlatform,
  NativeGroupedListSectionPlatform,
} from '@/components/native-grouped-list-platform';
import type { NativeIconName } from '@/components/native-icon';

export interface NativeGroupedListProps extends PropsWithChildren {
  largeTitle?: boolean;
  onBackPress?: () => void;
  showBackButton?: boolean;
  testID?: string;
  title?: string;
}

export function NativeGroupedList({
  children,
  largeTitle,
  onBackPress,
  showBackButton,
  testID,
  title,
}: NativeGroupedListProps) {
  return (
    <NativeGroupedListPlatform
      {...(largeTitle === undefined ? {} : { largeTitle })}
      {...(onBackPress ? { onBackPress } : {})}
      {...(showBackButton === undefined ? {} : { showBackButton })}
      {...(testID ? { testID } : {})}
      {...(title ? { title } : {})}
    >
      {children}
    </NativeGroupedListPlatform>
  );
}

export function NativeGroupedListSection({
  children,
  title,
}: PropsWithChildren<{ title: string }>) {
  return <NativeGroupedListSectionPlatform title={title}>{children}</NativeGroupedListSectionPlatform>;
}

export interface NativeGroupedListRowProps {
  description?: string;
  disabled?: boolean;
  icon: NativeIconName;
  onPress?: () => void;
  title: string;
  trailing?: ReactNode;
}

export function NativeGroupedListRow(props: NativeGroupedListRowProps) {
  return <NativeGroupedListRowPlatform {...props} />;
}
