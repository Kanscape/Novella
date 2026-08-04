import { FieldError, Input, Label, TextField } from 'heroui-native';
import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import {
  parseAvatarSource,
  resolveAvatarUrl,
  type AvatarSource,
} from '@novella/client-core';

import { NativeSegmentedControl } from '@/components/native-segmented-control';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { ProfileAvatar } from '@/components/profile-avatar';
import { useProfile } from '@/hooks/use-profile';
import { profile as profileUseCase } from '@/services/client';
import { createThemedStyles, useAppTheme } from '@/theme/app-theme';

const SOURCE_OPTIONS = [
  { label: 'Image URL', value: 'url' },
  { label: 'QQ avatar', value: 'qq' },
  { label: 'QQ group', value: 'qqGroup' },
] as const;

type AvatarDrafts = Record<AvatarSource, string>;

export function AvatarSettingsScreen() {
  const insets = useSafeAreaInsets();
  const styles = useAvatarSettingsScreenStyles();
  const { colors } = useAppTheme();
  const { error: loadError, profile, reload, status } = useProfile();
  const hydratedProfileId = useRef<number | null>(null);
  const [source, setSource] = useState<AvatarSource>('url');
  const [drafts, setDrafts] = useState<AvatarDrafts>({ qq: '', qqGroup: '', url: '' });
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!profile || hydratedProfileId.current === profile.id) return;
    hydratedProfileId.current = profile.id;
    const initial = parseAvatarSource(profile.avatarUrl);
    setSource(initial.source);
    setDrafts((current) => ({ ...current, [initial.source]: initial.value }));
  }, [profile]);

  if (!profile) {
    return (
      <NativeScreenScaffold
        largeTitle={false}
        onBackPress={() => router.back()}
        showBackButton
        title="Avatar"
      >
        <View style={styles.loadingRoot}>
          {status === 'loading' ? <ActivityIndicator color={colors.accent as string} /> : null}
          <Text style={styles.loadingTitle}>{loadError ?? 'Loading profile…'}</Text>
          {status !== 'loading' ? (
            <Pressable onPress={() => void reload()} style={styles.retryButton}>
              <Text style={styles.retryLabel}>Try again</Text>
            </Pressable>
          ) : null}
        </View>
      </NativeScreenScaffold>
    );
  }

  const value = drafts[source];
  const previewUrl = getPreviewUrl(source, value, profile.avatarUrl);

  async function save() {
    if (saving) return;
    setError(null);
    let avatarUrl: string;
    try {
      avatarUrl = resolveAvatarUrl(source, value);
    } catch (validationError) {
      setError(validationError instanceof Error ? validationError.message : 'Enter a valid avatar source.');
      return;
    }
    setSaving(true);
    try {
      await profileUseCase.setAvatar(avatarUrl);
      router.back();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : 'Unable to update your avatar.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <NativeScreenScaffold
      largeTitle={false}
      onBackPress={() => router.back()}
      showBackButton
      title="Avatar"
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={styles.root}
      >
        <ScrollView
          contentInsetAdjustmentBehavior="automatic"
          contentContainerStyle={[styles.content, { paddingBottom: Math.max(28, insets.bottom + 20) }]}
          keyboardShouldPersistTaps="handled"
        >
        <View style={styles.introduction}>
          <Text style={styles.title}>Change avatar</Text>
          <Text style={styles.description}>Choose an image source and preview it before saving.</Text>
        </View>

        <View style={styles.previewCard}>
          <ProfileAvatar avatarUrl={previewUrl} size={64} userName={profile.userName} />
          <View style={styles.previewCopy}>
            <Text numberOfLines={1} style={styles.previewName}>{profile.userName || 'Profile avatar'}</Text>
            <Text style={styles.previewDescription}>Live preview</Text>
          </View>
        </View>

        <NativeSegmentedControl
          enabled={!saving}
          onValueChange={(nextSource) => {
            setSource(nextSource);
            setError(null);
          }}
          options={SOURCE_OPTIONS}
          selectedValue={source}
        />

        <View style={styles.fieldGroup}>
          <TextField isDisabled={saving} isInvalid={error !== null}>
            <Label>{getFieldLabel(source)}</Label>
            <Input
              accessibilityLabel={getFieldLabel(source)}
              autoCapitalize="none"
              autoCorrect={false}
              keyboardType={source === 'url' ? 'url' : 'number-pad'}
              onChangeText={(nextValue) => {
                setDrafts((current) => ({ ...current, [source]: nextValue }));
                setError(null);
              }}
              onSubmitEditing={() => void save()}
              placeholder={getPlaceholder(source)}
              returnKeyType="done"
              value={value}
            />
            {error ? (
              <FieldError>{error}</FieldError>
            ) : (
              <Text style={styles.fieldHint}>{getSourceHint(source)}</Text>
            )}
          </TextField>
        </View>

        <Pressable
          accessibilityRole="button"
          disabled={saving}
          onPress={() => void save()}
          style={({ pressed }) => [styles.saveButton, pressed && styles.pressed, saving && styles.disabled]}
        >
          {saving ? <ActivityIndicator color="#FFFFFF" /> : null}
          <Text style={styles.saveLabel}>{saving ? 'Saving…' : 'Save avatar'}</Text>
        </Pressable>
        </ScrollView>
      </KeyboardAvoidingView>
    </NativeScreenScaffold>
  );
}

function getPreviewUrl(source: AvatarSource, value: string, fallback: string): string {
  if (!value.trim()) return fallback;
  try {
    return resolveAvatarUrl(source, value);
  } catch {
    return fallback;
  }
}

function getFieldLabel(source: AvatarSource): string {
  switch (source) {
    case 'url': return 'HTTPS image URL';
    case 'qq': return 'QQ number';
    case 'qqGroup': return 'QQ group number';
  }
}

function getPlaceholder(source: AvatarSource): string {
  switch (source) {
    case 'url': return 'https://example.com/avatar.jpg';
    case 'qq': return 'Enter QQ number';
    case 'qqGroup': return 'Enter QQ group number';
  }
}

function getSourceHint(source: AvatarSource): string {
  switch (source) {
    case 'url': return 'Image URLs must use HTTPS.';
    case 'qq': return 'Your QQ number will be exposed in the public avatar URL.';
    case 'qqGroup': return 'Your QQ group number will be exposed in the public avatar URL.';
  }
}

const useAvatarSettingsScreenStyles = createThemedStyles((colors) => ({
  content: { gap: 22, paddingHorizontal: 20, paddingTop: 24 },
  description: { color: colors.secondaryLabel, fontSize: 16, lineHeight: 23 },
  disabled: { opacity: 0.55 },
  fieldGroup: { gap: 8 },
  fieldHint: { color: colors.secondaryLabel, fontSize: 13, lineHeight: 18, paddingHorizontal: 2 },
  introduction: { gap: 7 },
  loadingRoot: { alignItems: 'center', backgroundColor: colors.background, flex: 1, gap: 14, justifyContent: 'center', padding: 24 },
  loadingTitle: { color: colors.secondaryLabel, fontSize: 15, textAlign: 'center' },
  pressed: { opacity: 0.72 },
  previewCard: { alignItems: 'center', backgroundColor: colors.card, borderRadius: 20, flexDirection: 'row', gap: 14, padding: 16 },
  previewCopy: { flex: 1, gap: 3 },
  previewDescription: { color: colors.secondaryLabel, fontSize: 14 },
  previewName: { color: colors.label, fontSize: 17, fontWeight: '700' },
  retryButton: { padding: 10 },
  retryLabel: { color: colors.accent, fontSize: 16, fontWeight: '600' },
  root: { backgroundColor: colors.background, flex: 1 },
  saveButton: { alignItems: 'center', backgroundColor: colors.accent, borderRadius: 14, flexDirection: 'row', gap: 8, justifyContent: 'center', minHeight: 52, paddingHorizontal: 18 },
  saveLabel: { color: '#FFFFFF', fontSize: 17, fontWeight: '600' },
  title: { color: colors.label, fontSize: 30, fontWeight: '700', letterSpacing: -0.6, lineHeight: 36 },
}));
