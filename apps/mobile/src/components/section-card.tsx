import type { PropsWithChildren } from 'react';
import { View } from 'react-native';

import { colors } from '@/theme/colors';

export function SectionCard({ children }: PropsWithChildren) {
  return <View style={styles.card}>{children}</View>;
}

const styles = {
  card: {
    backgroundColor: colors.card as string,
    borderColor: colors.separator as string,
    borderRadius: 16,
    borderWidth: 0.5,
    gap: 10,
    padding: 18,
    width: '100%',
  },
} as const;
