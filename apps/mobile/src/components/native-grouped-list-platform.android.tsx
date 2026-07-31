import {
  Column,
  HorizontalDivider,
  Host,
  ListItem,
  LazyColumn,
  Text,
  useMaterialColors,
} from '@expo/ui/jetpack-compose';
import { fillMaxWidth, padding, Shapes, clip, clickable } from '@expo/ui/jetpack-compose/modifiers';
import { useColorScheme } from 'react-native';
import type { PropsWithChildren } from 'react';

import { NativeTopAppBarScaffold } from '../../modules/novella-ui';

import { NativeIcon } from '@/components/native-icon';
import type { NativeGroupedListProps, NativeGroupedListRowProps } from '@/components/native-grouped-list';
import { DisclosureIcon } from '@/components/settings-row-accessories';
import { colors } from '@/theme/colors';

export function NativeGroupedListPlatform({
  children,
  largeTitle = false,
  onBackPress,
  showBackButton = false,
  testID,
  title,
}: NativeGroupedListProps) {
  const colorScheme = useColorScheme();
  const list = (
    <LazyColumn
      contentPadding={{ start: 16, top: 8, end: 16, bottom: 112 }}
      modifiers={[fillMaxWidth()]}
      verticalArrangement={{ spacedBy: 20 }}
    >
      {children}
    </LazyColumn>
  );

  return (
    <Host
      colorScheme={colorScheme}
      seedColor={colors.accent}
      style={{ flex: 1, width: '100%' }}
      {...(testID ? { testID } : {})}
      useViewportSizeMeasurement
    >
      {title ? (
        <NativeTopAppBarScaffold
          largeTitle={largeTitle}
          {...(onBackPress ? { onBackPress } : {})}
          showBackButton={showBackButton}
          title={title}
        >
          {list}
        </NativeTopAppBarScaffold>
      ) : list}
    </Host>
  );
}

export function NativeGroupedListSectionPlatform({ children, title }: PropsWithChildren<{ title: string }>) {
  const materialColors = useMaterialColors();
  const rows = Array.isArray(children) ? children : [children];

  return (
    <Column modifiers={[fillMaxWidth()]} verticalArrangement={{ spacedBy: 6 }}>
      <Text
        color={materialColors.onSurfaceVariant}
        modifiers={[padding(8, 0, 8, 0)]}
        style={{ typography: 'titleMedium' }}
      >
        {title}
      </Text>
      <Column
        modifiers={[fillMaxWidth(), clip(Shapes.RoundedCorner(22))]}
        verticalArrangement={{ spacedBy: 1 }}
      >
        {rows.map((row, index) => (
          <Column key={index} modifiers={[fillMaxWidth()]}>
            {row}
            {index < rows.length - 1 ? (
              <HorizontalDivider color={materialColors.outlineVariant} />
            ) : null}
          </Column>
        ))}
      </Column>
    </Column>
  );
}

export function NativeGroupedListRowPlatform({
  description,
  disabled,
  icon,
  onPress,
  title,
  trailing,
}: NativeGroupedListRowProps) {
  const materialColors = useMaterialColors();
  const modifiers = [
    fillMaxWidth(),
    ...(onPress && !disabled ? [clickable(onPress)] : []),
  ];

  return (
    <ListItem
      colors={{
        containerColor: materialColors.surfaceContainer,
        contentColor: materialColors.onSurface,
        leadingContentColor: colors.accent as string,
        supportingContentColor: materialColors.onSurfaceVariant,
        trailingContentColor: materialColors.onSurfaceVariant,
      }}
      modifiers={modifiers}
    >
      <ListItem.HeadlineContent>
        <Text color={materialColors.onSurface} style={{ typography: 'bodyLarge' }}>
          {title}
        </Text>
      </ListItem.HeadlineContent>
      {description ? (
        <ListItem.SupportingContent>
          <Text color={materialColors.onSurfaceVariant} style={{ typography: 'bodyMedium' }}>
            {description}
          </Text>
        </ListItem.SupportingContent>
      ) : null}
      <ListItem.LeadingContent>
        <NativeIcon color={colors.accent as string} name={icon} />
      </ListItem.LeadingContent>
      <ListItem.TrailingContent>
        {trailing ?? <DisclosureIcon />}
      </ListItem.TrailingContent>
    </ListItem>
  );
}
