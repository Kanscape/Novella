import { Image } from 'expo-image';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useRef } from 'react';
import {
  ActivityIndicator,
  Alert,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { IconArrowBackUp, IconMessage, IconRefresh, IconTrash } from '@tabler/icons-react-native';
import { PaperProvider } from 'react-native-paper';

import type { CommentItem, CommentReply, CommentUser } from '@novella/api-client';

import { BookCommentsNavigation } from '@/components/book-comments-navigation';
import { useBookDetailRouteTheme } from '@/components/book-detail-theme-provider';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { useComments } from '@/hooks/use-comments';
import type { BookDetailPalette } from '@/theme/book-detail-theme';

export interface BookCommentsScreenProps {
  bookId: number;
}

interface ReplyTarget {
  parentId: number;
  replyId?: number;
  userName: string;
}

export function BookCommentsScreen({ bookId }: BookCommentsScreenProps) {
  const detailTheme = useBookDetailRouteTheme(bookId, null, true);
  const { palette } = detailTheme;
  const {
    deleteComment,
    error,
    isLoading,
    isLoadingMore,
    loadMore,
    page,
    refresh,
  } = useComments(bookId);
  const hasFocused = useRef(false);

  useFocusEffect(
    useCallback(() => {
      if (hasFocused.current) void refresh();
      hasFocused.current = true;
    }, [refresh]),
  );

  const openComposer = useCallback((target?: ReplyTarget) => {
    router.push({
      pathname: '/book/[id]/comment-compose',
      params: {
        id: String(bookId),
        ...(target
          ? {
              parentId: String(target.parentId),
              ...(target.replyId === undefined ? {} : { replyId: String(target.replyId) }),
              userName: target.userName,
            }
          : {}),
      },
    });
  }, [bookId]);

  function confirmDelete(commentId: number) {
    Alert.alert('Delete comment', 'This action cannot be undone.', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => void deleteComment(commentId) },
    ]);
  }

  return (
    <PaperProvider theme={detailTheme.paperTheme}>
      <BookCommentsNavigation onCompose={() => openComposer()} palette={palette} />
      <NativeScreenScaffold
        actions={[
          {
            accessibilityLabel: 'Write a comment',
            icon: 'pencil',
            id: 'compose',
          },
        ]}
        largeTitle={false}
        onActionPress={(id) => {
          if (id === 'compose') openComposer();
        }}
        onBackPress={() => router.back()}
        showBackButton
        title="Comments"
        containerColor={palette.surface}
        contentColor={palette.onSurface}
      >
        <View style={[styles.root, { backgroundColor: palette.surface }]}>
          <FlatList
            contentInsetAdjustmentBehavior="automatic"
            contentContainerStyle={styles.content}
            data={page?.items ?? []}
            keyExtractor={(item) => String(item.id)}
            ListEmptyComponent={
              !isLoading && !error ? (
                <View style={styles.emptyState}>
                  <IconMessage color={palette.onSurfaceVariant} size={44} strokeWidth={1.5} />
                  <Text style={[styles.emptyText, { color: palette.onSurfaceVariant }]}>No comments yet.</Text>
                </View>
              ) : null
            }
            ListFooterComponent={
              isLoadingMore ? <ActivityIndicator color={palette.primary} /> : null
            }
            ListHeaderComponent={isLoading || error ? (
              <View style={styles.header}>
                {isLoading ? <ActivityIndicator color={palette.primary} /> : null}
                {error ? (
                  <View style={styles.errorBlock}>
                    <Text style={[styles.errorText, { color: palette.error }]}>{error}</Text>
                    <Pressable
                      accessibilityLabel="Reload comments"
                      accessibilityRole="button"
                      onPress={() => void refresh()}
                      style={({ pressed }) => [styles.inlineButton, pressed && styles.pressed]}
                    >
                      <IconRefresh color={palette.primary} size={17} strokeWidth={2} />
                      <Text style={[styles.inlineButtonLabel, { color: palette.primary }]}>Try again</Text>
                    </Pressable>
                  </View>
                ) : null}
              </View>
            ) : null}
            onEndReached={loadMore}
            onEndReachedThreshold={0.35}
            renderItem={({ item }) => (
              <CommentRow
                item={item}
                onDelete={confirmDelete}
                onReply={openComposer}
                palette={palette}
              />
            )}
            showsVerticalScrollIndicator={false}
          />
        </View>
      </NativeScreenScaffold>
    </PaperProvider>
  );
}

function CommentRow({
  item,
  onDelete,
  onReply,
  palette,
}: {
  item: CommentItem;
  onDelete: (id: number) => void;
  onReply: (target: ReplyTarget) => void;
  palette: BookDetailPalette;
}) {
  return (
    <View style={styles.commentBlock}>
      <View style={styles.commentRow}>
        <Avatar palette={palette} size={40} user={item.user} />
        <View style={styles.commentBody}>
          <Text style={[styles.userName, { color: palette.onSurface }]}>
            {item.user.userName}
          </Text>
          <Text selectable style={[styles.commentText, { color: palette.onSurface }]}>
            {item.content.trim()}
          </Text>
          <CommentActions
            canDelete={item.canEdit}
            createdAt={item.createdAt}
            onDelete={() => onDelete(item.id)}
            onReply={() => onReply({ parentId: item.id, userName: item.user.userName })}
            palette={palette}
            variant="comment"
          />
        </View>
      </View>
      {item.replies.length > 0 ? (
        <View style={[styles.replies, { borderLeftColor: palette.outlineVariant }]}>
          {item.replies.map((reply) => (
            <ReplyRow
              key={reply.id}
              onDelete={onDelete}
              onReply={onReply}
              parentId={item.id}
              palette={palette}
              reply={reply}
            />
          ))}
        </View>
      ) : null}
    </View>
  );
}

function ReplyRow({
  onDelete,
  onReply,
  parentId,
  palette,
  reply,
}: {
  onDelete: (id: number) => void;
  onReply: (target: ReplyTarget) => void;
  parentId: number;
  palette: BookDetailPalette;
  reply: CommentReply;
}) {
  return (
    <View style={styles.replyRow}>
      <View style={styles.replyIdentity}>
        <Avatar palette={palette} size={24} user={reply.user} />
        <Text style={[styles.replyIdentityText, { color: palette.onSurface }]}>
          <Text style={[styles.replyName, { color: palette.onSurface }]}>
            {reply.user.userName}
          </Text>
          {reply.replyToUser ? (
            <>
              <Text style={[styles.replyConnector, { color: palette.onSurfaceVariant }]}> replied to </Text>
              <Text style={[styles.replyName, { color: palette.onSurface }]}>
                {reply.replyToUser.userName}
              </Text>
            </>
          ) : null}
        </Text>
      </View>
      <Text selectable style={[styles.commentText, { color: palette.onSurface }]}>
        {reply.content.trim()}
      </Text>
      <CommentActions
        canDelete={reply.canEdit}
        createdAt={reply.createdAt}
        onDelete={() => onDelete(reply.id)}
        onReply={() =>
          onReply({ parentId, replyId: reply.id, userName: reply.user.userName })
        }
        palette={palette}
        variant="reply"
      />
    </View>
  );
}

function CommentActions({
  canDelete,
  createdAt,
  onDelete,
  onReply,
  palette,
  variant,
}: {
  canDelete: boolean;
  createdAt: string;
  onDelete: () => void;
  onReply: () => void;
  palette: BookDetailPalette;
  variant: 'comment' | 'reply';
}) {
  const iconSize = variant === 'comment' ? 18 : 16;
  return (
    <View style={styles.commentActions}>
      <Text style={[
        styles.timestamp,
        { color: palette.onSurfaceVariant },
        variant === 'reply' && styles.replyTimestamp,
      ]}>
        {formatRelativeTime(createdAt)}
      </Text>
      <View style={styles.actionButtons}>
        <Pressable
          accessibilityLabel="Reply"
          accessibilityRole="button"
          onPress={onReply}
          style={({ pressed }) => [styles.smallAction, pressed && styles.pressed]}
        >
          <IconArrowBackUp
            color={palette.onSurfaceVariant}
            size={iconSize}
            strokeWidth={2}
          />
        </Pressable>
        {canDelete ? (
          <Pressable
            accessibilityLabel="Delete comment"
            accessibilityRole="button"
            onPress={onDelete}
            style={({ pressed }) => [styles.smallAction, pressed && styles.pressed]}
          >
            <IconTrash color={palette.error} size={iconSize} strokeWidth={2} />
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

function Avatar({
  palette,
  size,
  user,
}: {
  palette: BookDetailPalette;
  size: number;
  user: CommentUser;
}) {
  return user.avatarUrl ? (
    <Image accessibilityLabel={`${user.userName} avatar`} source={user.avatarUrl} style={{ borderRadius: size / 2, height: size, width: size }} />
  ) : (
    <View style={[
      styles.avatarFallback,
      {
        backgroundColor: palette.surfaceContainerHighest,
        borderRadius: size / 2,
        height: size,
        width: size,
      },
    ]}>
      <Text style={[styles.avatarLabel, { color: palette.onSurface, fontSize: size * 0.4 }]}>
        {user.userName.trim().slice(0, 1).toUpperCase() || '?'}
      </Text>
    </View>
  );
}

function formatRelativeTime(value: string): string {
  const elapsed = Math.max(0, Date.now() - Date.parse(value));
  const minutes = Math.floor(elapsed / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  if (days < 26) return `${days}d ago`;
  if (days < 46) return '1mo ago';
  if (days < 320) return `${Math.round(days / 30.4)}mo ago`;
  if (days < 548) return '1y ago';
  return `${Math.round(days / 365.25)}y ago`;
}

const styles = StyleSheet.create({
  actionButtons: { alignItems: 'center', flexDirection: 'row', gap: 8 },
  avatarFallback: { alignItems: 'center', justifyContent: 'center' },
  avatarLabel: { fontWeight: '700' },
  commentActions: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', minHeight: 32 },
  commentBlock: { paddingBottom: 8 },
  commentBody: { flex: 1, gap: 4 },
  commentRow: { alignItems: 'flex-start', flexDirection: 'row', gap: 16, paddingHorizontal: 16, paddingVertical: 8 },
  commentText: { fontSize: 14, lineHeight: 19 },
  content: { gap: 8, paddingBottom: 48, paddingTop: 8 },
  emptyState: { alignItems: 'center', gap: 12, paddingHorizontal: 32, paddingVertical: 64 },
  emptyText: { fontSize: 15, textAlign: 'center' },
  errorBlock: { alignItems: 'center', gap: 8, paddingHorizontal: 16 },
  errorText: { fontSize: 14, lineHeight: 20, textAlign: 'center' },
  header: { gap: 16, paddingBottom: 10, paddingHorizontal: 16, paddingTop: 12 },
  inlineButton: { alignItems: 'center', flexDirection: 'row', gap: 6, padding: 6 },
  inlineButtonLabel: { fontSize: 14, fontWeight: '600' },
  pressed: { opacity: 0.68 },
  replies: { borderLeftWidth: 2, gap: 12, marginBottom: 8, marginLeft: 72, marginRight: 16, paddingLeft: 12 },
  replyConnector: { fontWeight: '400' },
  replyIdentity: { alignItems: 'center', flexDirection: 'row', gap: 8 },
  replyIdentityText: { flex: 1, fontSize: 12, lineHeight: 16 },
  replyName: { fontWeight: '700' },
  replyRow: { gap: 4 },
  replyTimestamp: { fontSize: 10 },
  root: { flex: 1 },
  smallAction: { alignItems: 'center', height: 32, justifyContent: 'center', minWidth: 32, paddingHorizontal: 5 },
  timestamp: { fontSize: 12 },
  userName: { fontSize: 14, fontWeight: '700', lineHeight: 19 },
});
