import type { StyleProp, ViewStyle } from 'react-native';

export interface NativeSegmentedControlOption {
  label: string;
  value: string;
}

export interface NativeSegmentedControlProps {
  enabled?: boolean;
  onValueChange?: (value: string) => void;
  options: readonly NativeSegmentedControlOption[];
  selectedValue: string;
  style?: StyleProp<ViewStyle>;
}

export function NativeSegmentedControl(_props: NativeSegmentedControlProps): null {
  return null;
}
