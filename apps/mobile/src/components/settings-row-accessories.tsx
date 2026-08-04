import { NativeIcon } from '@/components/native-icon';
import { useAppTheme } from '@/theme/app-theme';
import { Text } from '@expo/ui';

export function DisclosureIcon() {
  const { colors } = useAppTheme();
  return <NativeIcon color={colors.secondaryLabel as string} name="chevronRight" size={20} />;
}

export function NativeListValue({ children }: { children: string }) {
  const { colors } = useAppTheme();
  return (
    <Text textStyle={{ color: colors.secondaryLabel as string, fontSize: 14 }}>
      {children}
    </Text>
  );
}
