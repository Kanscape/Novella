import { Alert } from 'react-native';

/**
 * Non-Android platforms keep the system alert (RN `Alert.alert`). Only
 * Android renders the Material 3 Expressive dialog via `NativeAlertHost`.
 */

export type NativeAlertButtonStyle = 'default' | 'cancel' | 'destructive';

export interface NativeAlertButton {
  text: string;
  style?: NativeAlertButtonStyle;
  onPress?: () => void;
}

/** Drop-in replacement for `Alert.alert(title, message?, buttons?)`. */
export function showAlert(
  title: string,
  message?: string,
  buttons?: NativeAlertButton[],
): void {
  Alert.alert(title, message, buttons);
}

/** No-op on non-Android platforms. */
export function NativeAlertHost(): null {
  return null;
}
