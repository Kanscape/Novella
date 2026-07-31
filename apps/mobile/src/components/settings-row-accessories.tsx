import { NativeIcon } from '@/components/native-icon';
import { colors } from '@/theme/colors';
import { Text } from '@expo/ui';

export function DisclosureIcon() {
  return <NativeIcon color={colors.secondaryLabel as string} name="chevronRight" size={20} />;
}

export function NativeListValue({ children }: { children: string }) {
  return (
    <Text textStyle={{ color: colors.secondaryLabel as string, fontSize: 14 }}>
      {children}
    </Text>
  );
}
