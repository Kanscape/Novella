import { router, useFocusEffect } from 'expo-router';
import { useCallback, useRef } from 'react';
import {
  Alert,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { IconArrowBackUp, IconMessage, IconRefresh, IconTrash } from '@tabler/icons-react-native';
import { PaperProvider } from 'react-native-paper';
import { Skeleton } from 'heroui-native';

import type { CommentItem, CommentReply, CommentUser } from '@novella/api-client';

import { BookCommentsNavigation } from '@/components/book-comments-navigation';
import { useBookDetailRouteTheme } from '@/components/book-detail-theme-provider';
import { NativeScreenScaffold } from '@/components/native-screen-scaffold';
import { ProfileAvatar } from '@/components/profile-avatar';
import { useComments } from '@/hooks/use-comments';
import { consumeCommentsChanged } from '@/services/comment-events';
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
  const detailTheme = useBookDetailRouteTheme(bookId, null, null, true);
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
      // Only refresh when a comment was actually posted (or deleted) while this
      // screen was not focused. Dismissing the composer without posting must not
      // cause a refresh — and the callback must stay referentially stable, or the
      // focus effect re-subscribes on every render and loops (Maximum update depth).
      if (hasFocused.current && consumeCommentsChanged()) void refresh();
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
      <BookCommentsNavigation onCompose={openComposer} palette={palette} />
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
              isLoading ? (
                <CommentsSkeleton palette={palette} />
              ) : error ? (
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
              ) : (
                <View style={styles.emptyState}>
                  <IconMessage color={palette.onSurfaceVariant} size={44} strokeWidth={1.5} />
                  <Text style={[styles.emptyText, { color: palette.onSurfaceVariant }]}>No comments yet.</Text>
                </View>
              )
            }
            ListFooterComponent={
              isLoadingMore ? <CommentsSkeleton palette={palette} rows={1} /> : null
            }
            ListHeaderComponent={
              error && page ? (
                <View style={styles.header}>
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
                </View>
              ) : null
            }
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

function CommentsSkeleton({ palette, rows = 8 }: { palette: BookDetailPalette; rows?: number }) {
  return (
    <View
      accessibilityElementsHidden
      importantForAccessibility="no-hide-descendants"
      style={styles.skeletonList}
    >
      {Array.from({ length: rows }, (_, index) => (
        <View key={`comment-skeleton-${index}`} style={styles.skeletonRow}>
          <Skeleton
            animation={{ entering: false, exiting: false }}
            style={[styles.skeletonAvatar, { backgroundColor: palette.surfaceContainerHighest }]}
            variant="shimmer"
          />
          <View style={styles.skeletonBody}>
            <Skeleton
              animation={{ entering: false, exiting: false }}
              style={[styles.skeletonLine, styles.skeletonName, { backgroundColor: palette.surfaceContainerHighest }]}
              variant="shimmer"
            />
            <Skeleton
              animation={{ entering: false, exiting: false }}
              style={[styles.skeletonLine, { backgroundColor: palette.surfaceContainerHighest }]}
              variant="shimmer"
            />
            <Skeleton
              animation={{ entering: false, exiting: false }}
              style={[styles.skeletonLine, styles.skeletonTextShort, { backgroundColor: palette.surfaceContainerHighest }]}
              variant="shimmer"
            />
            <Skeleton
              animation={{ entering: false, exiting: false }}
              style={[styles.skeletonLine, styles.skeletonAction, { backgroundColor: palette.surfaceContainerHighest }]}
              variant="shimmer"
            />
          </View>
        </View>
      ))}
    </View>
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
  return (
    <ProfileAvatar
      avatarUrl={user.avatarUrl}
      fallbackBackground={palette.surfaceContainerHighest}
      fallbackColor={palette.onSurface}
      size={size}
      userName={user.userName}
    />
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
  skeletonAction: { height: 11, marginTop: 4, width: '32%' },
  skeletonAvatar: { borderRadius: 20, height: 40, overflow: 'hidden', width: 40 },  skeletonBody: { flex: 1, gap: 7, paddingTop: 3 },
  skeletonLine: { borderRadius: 6, height: 13, overflow: 'hidden', width: '100%' },
  skeletonList: { gap: 22, paddingHorizontal: 16, paddingTop: 8 },
  skeletonName: { height: 12, width: '42%' },
  skeletonRow: { flexDirection: 'row', gap: 16 },
  skeletonTextShort: { width: '72%' },
  replyIdentityText: { flex: 1, fontSize: 12, lineHeight: 16 },
  replyName: { fontWeight: '700' },
  replyRow: { gap: 4 },
  replyTimestamp: { fontSize: 10 },
  root: { flex: 1 },
  smallAction: { alignItems: 'center', height: 32, justifyContent: 'center', minWidth: 32, paddingHorizontal: 5 },
  timestamp: { fontSize: 12 },
  userName: { fontSize: 14, fontWeight: '700', lineHeight: 19 },
});
