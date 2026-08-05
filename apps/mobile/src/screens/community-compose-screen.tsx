import { router, Stack } from 'expo-router';
import {
  Chip,
  FieldError,
  Input,
  Label,
  Spinner,
  TextField,
} from 'heroui-native';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';

import type { CommunityCatalogBoard } from '@novella/api-client';
import {
  COMMUNITY_STORAGE_KEYS,
  CommunitySpeechBlockedError,
  CommunitySpeechRulesUnavailableError,
} from '@novella/client-core';

import { CommunityPublishNavigation } from '@/components/community/community-navigation';
import {
  CommunityRichEditor,
  type CommunityRichEditorHandle,
} from '@/components/community/community-rich-editor';
import {
  CommunityErrorState,
  CommunityPaperProvider,
} from '@/components/community/community-ui';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { showAlert } from '@/components/native-alert-dialog';
import { community, communitySpeechGuard, storage } from '@/services/client';
import { createThemedStyles, useAppTheme } from '@/theme/app-theme';

export function CommunityComposeScreen({
  initialBoardKey = '',
  initialSubCategoryKey = '',
}: {
  initialBoardKey?: string;
  initialSubCategoryKey?: string;
}) {
  const styles = useCommunityComposeStyles();
  const { colors } = useAppTheme();
  const editorRef = useRef<CommunityRichEditorHandle>(null);
  const [boards, setBoards] = useState<CommunityCatalogBoard[]>([]);
  const [boardKey, setBoardKey] = useState(initialBoardKey);
  const [subCategoryKey, setSubCategoryKey] = useState(initialSubCategoryKey);
  const [title, setTitle] = useState('');
  const [contentText, setContentText] = useState('');
  const [loading, setLoading] = useState(true);
  const [loadToken, setLoadToken] = useState(0);
  const [publishing, setPublishing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [noticeAccepted, setNoticeAccepted] = useState(false);
  const [speechDisabled, setSpeechDisabled] = useState(communitySpeechGuard.getSnapshot());

  useEffect(() => {
    let active = true;
    const unsubscribe = communitySpeechGuard.subscribe((disabled) => {
      setSpeechDisabled(disabled);
      if (disabled) router.replace('/community');
    });
    void Promise.all([
      community.loadHome({ page: 1, size: 1 }),
      communitySpeechGuard.isSpeechDisabled(),
      storage.get(COMMUNITY_STORAGE_KEYS.postNoticeAccepted),
    ]).then(([home, disabled, notice]) => {
      if (!active) return;
      if (disabled) {
        router.replace('/community');
        return;
      }
      setBoards(home.catalogBoards.filter((board) => board.key !== 'all'));
      if (initialBoardKey && home.catalogBoards.some((board) => board.key === initialBoardKey)) {
        setBoardKey(initialBoardKey);
      }
      setNoticeAccepted(notice === 'true');
      if (notice !== 'true') showFirstPostNotice();
      setLoading(false);
    }).catch((loadError: unknown) => {
      if (!active) return;
      setError(loadError instanceof Error ? loadError.message : 'Unable to prepare the composer.');
      setLoading(false);
    });
    return () => {
      active = false;
      unsubscribe();
    };
  }, [initialBoardKey, initialSubCategoryKey, loadToken]);

  const selectedBoard = useMemo(
    () => boards.find((board) => board.key === boardKey) ?? null,
    [boardKey, boards],
  );
  const canPublish = Boolean(
    noticeAccepted &&
    !speechDisabled &&
    !publishing &&
    boardKey &&
    title.trim().length >= 6 &&
    title.trim().length <= 60 &&
    contentText.trim().length >= 20 &&
    (!selectedBoard?.subCategories.length || subCategoryKey),
  );

  async function acceptNotice() {
    setError(null);
    try {
      await storage.set(COMMUNITY_STORAGE_KEYS.postNoticeAccepted, 'true');
      setNoticeAccepted(true);
    } catch (storageError) {
      setError(
        storageError instanceof Error
          ? storageError.message
          : 'Unable to save Community notice acceptance.',
      );
    }
  }

  const showFirstPostNotice = useCallback(() => {
    showAlert(
      'Before you post',
      'Community posts are public. Be respectful, avoid requesting or distributing restricted material, and never share private information.\n\n'
        + '• Choose a relevant board and category.\n'
        + '• Keep titles descriptive and content constructive.\n'
        + '• Moderation rules are checked on this device before publishing.',
      [
        { style: 'cancel', text: 'Cancel', onPress: () => router.back() },
        { onPress: () => void acceptNotice(), text: 'I understand' },
      ],
    );
  }, [acceptNotice]);

  async function publish() {
    if (!canPublish) return;
    setPublishing(true);
    setError(null);
    try {
      const contentHtml = await editorRef.current?.getHtml() ?? '';
      const thread = await community.createThread({
        boardKey,
        subCategoryKey,
        title,
        contentHtml,
        contentText,
      });
      router.replace({
        pathname: '/thread/[id]',
        params: { id: String(thread.id), initialTitle: thread.title },
      });
    } catch (publishError) {
      if (publishError instanceof CommunitySpeechBlockedError) {
        router.replace('/community');
        return;
      }
      showAlert(
        'Unable to publish the discussion',
        publishError instanceof CommunitySpeechRulesUnavailableError
          ? 'Community rules are unavailable. Check your connection and try again.'
          : publishError instanceof Error
            ? publishError.message
            : 'Unable to publish the discussion.',
      );
    } finally {
      setPublishing(false);
    }
  }

  return (
    <CommunityPaperProvider>
      <>
        <Stack.Screen options={{ title: 'New post' }} />
      <NativeScreenScaffold
        actions={[
          {
            accessibilityLabel: 'Publish discussion',
            enabled: canPublish,
            icon: 'check',
            id: 'publish',
          },
        ]}
        largeTitle={false}
        onActionPress={(id) => {
          if (id === 'publish') void publish();
        }}
        onBackPress={() => router.back()}
        showBackButton
        title="New post"
      >
        <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 88 : 0}
        style={styles.root}
      >
        {loading ? (
          <View style={styles.center}><Spinner /></View>
        ) : (
          <ScrollView
            contentContainerStyle={styles.content}
            contentInsetAdjustmentBehavior="automatic"
            keyboardShouldPersistTaps="handled"
            nestedScrollEnabled
          >
            {error ? (
              <CommunityErrorState
                description={error}
                onRetry={() => {
                  setError(null);
                  if (boards.length === 0) {
                    setLoading(true);
                    setLoadToken((current) => current + 1);
                  }
                }}
                title={boards.length === 0 ? 'Unable to prepare the composer' : 'Unable to publish'}
              />
            ) : null}

            <View style={styles.fieldGroup}>
              <Text style={styles.fieldHeading}>Board</Text>
              <View style={styles.chips}>
                {boards.map((board) => (
                  <Chip
                    accessibilityState={{ selected: board.key === boardKey }}
                    color={board.key === boardKey ? 'accent' : 'default'}
                    key={board.key}
                    onPress={() => {
                      setBoardKey(board.key);
                      setSubCategoryKey('');
                    }}
                    variant={board.key === boardKey ? 'primary' : 'soft'}
                  >
                    {board.title}
                  </Chip>
                ))}
              </View>
              {selectedBoard?.description ? <Text style={styles.helper}>{selectedBoard.description}</Text> : null}
            </View>

            {selectedBoard?.subCategories.length ? (
              <View style={styles.fieldGroup}>
                <Text style={styles.fieldHeading}>Category</Text>
                <View style={styles.chips}>
                  {selectedBoard.subCategories.map((category) => (
                    <Chip
                      accessibilityState={{ selected: category.key === subCategoryKey }}
                      color={category.key === subCategoryKey ? 'accent' : 'default'}
                      key={category.key}
                      onPress={() => setSubCategoryKey(category.key)}
                      variant={category.key === subCategoryKey ? 'primary' : 'soft'}
                    >
                      {category.label}
                    </Chip>
                  ))}
                </View>
                {!subCategoryKey ? <Text style={styles.validation}>Select a category.</Text> : null}
              </View>
            ) : null}

            <TextField isInvalid={title.length > 0 && title.trim().length < 6}>
              <Label>
                <Label.Text styles={{ text: styles.fieldHeading }}>Title</Label.Text>
              </Label>
              <Input
                editable={!publishing}
                maxLength={60}
                onChangeText={setTitle}
                placeholder="A clear discussion title"
                value={title}
              />
              <View style={styles.counterRow}>
                <FieldError>Title must contain at least 6 characters.</FieldError>
                <Text style={styles.counter}>{title.length}/60</Text>
              </View>
            </TextField>

            <View style={styles.fieldGroup}>
              <View style={styles.counterRow}>
                <Text style={styles.fieldHeading}>Post</Text>
                <Text style={styles.counter}>{contentText.trim().length} characters</Text>
              </View>
              <CommunityRichEditor
                editable={!publishing}
                onTextChange={setContentText}
                placeholder="Share your thoughts with the Community…"
                ref={editorRef}
              />
              {contentText.length > 0 && contentText.trim().length < 20 ? (
                <Text style={styles.validation}>Post content must contain at least 20 characters.</Text>
              ) : null}
            </View>
          </ScrollView>
        )}
      </KeyboardAvoidingView>
      </NativeScreenScaffold>
        <CommunityPublishNavigation disabled={!canPublish} onPublish={() => void publish()} />
      </>
    </CommunityPaperProvider>
  );
}

const useCommunityComposeStyles = createThemedStyles((colors) => ({
  center: { alignItems: 'center', flex: 1, justifyContent: 'center' },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  content: { gap: 20, padding: 16, paddingBottom: 48 },
  counter: { color: colors.secondaryLabel, fontSize: 12 },
  counterRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' },
  fieldGroup: { gap: 9 },
  fieldHeading: { color: colors.label, fontSize: 15, fontWeight: '700' },
  helper: { color: colors.secondaryLabel, fontSize: 13, lineHeight: 19 },
  root: { backgroundColor: colors.background, flex: 1 },
  validation: { color: colors.error, fontSize: 12 },
}));
