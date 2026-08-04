import { FieldGroup, Host, ListItem } from '@expo/ui';
import type { PropsWithChildren } from 'react';

import { NativeIcon } from '@/components/native-icon';
import { DisclosureIcon } from '@/components/settings-row-accessories';
import type { NativeGroupedListProps, NativeGroupedListRowProps } from '@/components/native-grouped-list';
import { useAppTheme } from '@/theme/app-theme';

export function NativeGroupedListPlatform({ children, testID }: NativeGroupedListProps) {
  const { colors } = useAppTheme();
  return (
    <Host seedColor={colors.accent} style={{ flex: 1, width: '100%' }} testID={testID}>
      <FieldGroup>{children}</FieldGroup>
    </Host>
  );
}

export function NativeGroupedListSectionPlatform({ children, title }: PropsWithChildren<{ title: string }>) {
  return <FieldGroup.Section title={title}>{children}</FieldGroup.Section>;
}

export function NativeGroupedListRowPlatform({
  description,
  disabled,
  icon,
  onPress,
  title,
  trailing,
}: NativeGroupedListRowProps) {
  const { colors } = useAppTheme();
  return (
    <ListItem
      leading={<NativeIcon color={colors.accent as string} name={icon} />}
      {...(onPress && !disabled ? { onPress } : {})}
      {...(description ? { supportingText: description } : {})}
      trailing={trailing ?? <DisclosureIcon />}
    >
      {title}
    </ListItem>
  );
}
