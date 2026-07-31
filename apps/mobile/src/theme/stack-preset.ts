import { isLiquidGlassAvailable } from 'expo-glass-effect';
import Stack from 'expo-router/stack';

import { colors } from '@/theme/colors';

type StackScreenOptions = React.ComponentProps<typeof Stack>['screenOptions'];

const hasLiquidGlass = isLiquidGlassAvailable();

export const systemScreenStackPreset: StackScreenOptions = {
  contentStyle: { backgroundColor: colors.background },
  headerBackButtonDisplayMode: 'minimal',
  headerBlurEffect: hasLiquidGlass ? undefined : 'systemMaterial',
  headerLargeTitleShadowVisible: false,
  headerShadowVisible: false,
  headerTintColor: colors.accent,
  headerTitleStyle: { color: colors.label as string },
  headerTransparent: hasLiquidGlass,
};
