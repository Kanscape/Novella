import { Image } from 'expo-image';
import { StyleSheet, Text, View } from 'react-native';
import { IconUser } from '@tabler/icons-react-native';

import { colors } from '@/theme/colors';

export interface ProfileAvatarProps {
  avatarUrl: string;
  size?: number;
  userName: string;
}

export function ProfileAvatar({ avatarUrl, size = 48, userName }: ProfileAvatarProps) {
  const fallback = userName.trim().slice(0, 1).toUpperCase();
  const frameStyle = { borderRadius: size / 2, height: size, width: size };
  if (avatarUrl.trim()) {
    return (
      <Image
        accessibilityLabel={`${userName || 'User'} avatar`}
        contentFit="cover"
        source={avatarUrl.trim()}
        style={frameStyle}
        transition={160}
      />
    );
  }
  return (
    <View style={[styles.fallback, frameStyle]}>
      {fallback ? (
        <Text style={[styles.fallbackText, { fontSize: size * 0.4 }]}>{fallback}</Text>
      ) : (
        <IconUser color={colors.secondaryLabel as string} size={size * 0.48} strokeWidth={1.8} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  fallback: {
    alignItems: 'center',
    backgroundColor: colors.surfaceContainerHighest as string,
    justifyContent: 'center',
  },
  fallbackText: { color: colors.label as string, fontWeight: '700' },
});
