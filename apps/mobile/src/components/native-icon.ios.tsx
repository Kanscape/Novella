import { Image } from '@expo/ui/swift-ui';
import { accessibilityLabel } from '@expo/ui/swift-ui/modifiers';

import type { NativeIconName } from '@/components/native-icon-types';

type SystemName = NonNullable<React.ComponentProps<typeof Image>['systemName']>;

const icons: Record<NativeIconName, SystemName> = {
  account: 'person.crop.circle',
  announcement: 'megaphone.fill',
  appearance: 'paintpalette',
  badgeAi: 'cpu.fill',
  badgeEdit: 'pencil.line',
  badgeFilter1: '1.circle.fill',
  badgeFilter2: '2.circle.fill',
  badgeFilter3: '3.circle.fill',
  badgeFilter4: '4.circle.fill',
  badgeFilter5: '5.circle.fill',
  badgeFilter6: '6.circle.fill',
  badgeHistory: 'text.book.closed.fill',
  badgeJapanese: 'book.closed.fill',
  badgeLevel: 'circle.hexagongrid.fill',
  badgeReply: 'arrowshape.turn.up.left.fill',
  badgeTranslate: 'character.book.closed.fill',
  books: 'books.vertical',
  cache: 'internaldrive',
  chevronRight: 'chevron.right',
  cloudSync: 'icloud.and.arrow.up',
  clock: 'clock',
  community: 'person.3',
  content: 'rectangle.3.group',
  discover: 'sparkles',
  error: 'exclamationmark.triangle.fill',
  info: 'info.circle',
  progress: 'arrow.triangle.2.circlepath',
  reader: 'book.pages',
  search: 'magnifyingglass',
  settings: 'gearshape',
  sync: 'arrow.triangle.2.circlepath',
};

export type { NativeIconName } from '@/components/native-icon-types';

export function NativeIcon({
  accessibilityLabel: label,
  color,
  name,
  size = 22,
}: {
  accessibilityLabel?: string;
  color: string;
  name: NativeIconName;
  size?: number;
}) {
  return (
    <Image
      color={color}
      size={size}
      systemName={icons[name]}
      {...(label ? { modifiers: [accessibilityLabel(label)] } : {})}
    />
  );
}
