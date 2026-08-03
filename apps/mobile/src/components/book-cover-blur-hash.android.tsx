import { Host } from '@expo/ui';
import { fillMaxSize } from '@expo/ui/jetpack-compose/modifiers';
import { Image } from 'expo-image';
import { StyleSheet } from 'react-native';

import { NativeBlurHash } from '../../modules/novella-ui';

import type { ExpoBlurHashPlaceholder } from '@/services/blurhash';

export function BookCoverBlurHash({
  placeholder,
}: {
  placeholder: ExpoBlurHashPlaceholder;
}) {
  return (
    <>
      <Image
        accessibilityElementsHidden
        contentFit="cover"
        source={placeholder}
        style={StyleSheet.absoluteFill}
      />
      <Host style={StyleSheet.absoluteFill} useViewportSizeMeasurement>
        <NativeBlurHash
          blurHash={placeholder.blurhash}
          height={placeholder.height}
          modifiers={[fillMaxSize()]}
          width={placeholder.width}
        />
      </Host>
    </>
  );
}
