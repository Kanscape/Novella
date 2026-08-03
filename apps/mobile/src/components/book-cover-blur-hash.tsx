import { Image } from 'expo-image';
import { StyleSheet } from 'react-native';

import type { ExpoBlurHashPlaceholder } from '@/services/blurhash';

export function BookCoverBlurHash({
  placeholder,
}: {
  placeholder: ExpoBlurHashPlaceholder;
}) {
  return (
    <Image
      accessibilityElementsHidden
      contentFit="cover"
      source={placeholder}
      style={StyleSheet.absoluteFill}
    />
  );
}
