import { IconHeart, IconMessageCircle } from "@tabler/icons-react-native";
import { router } from "expo-router";
import { Card, Chip } from "react-native-paper";
import { useState } from "react";
import {
  Pressable,
  RefreshControl,
  ScrollView,
  Text,
  View,
} from "react-native";

import type {
  CommunityFeedItem,
  CommunityMyReplyItem,
} from "@novella/api-client";

import {
  CommunityEmptyState,
  CommunityErrorState,
  CommunityPaperProvider,
  CommunityThreadCard,
  CommunityThreadSkeleton,
} from "@/components/community/community-ui";
import { NativeScreenScaffold } from "@/components/native-screen-scaffold";
import {
  NativeSegmentedControl,
  type NativeSegmentedControlOption,
} from "@/components/native-segmented-control";
import { useMyCommunity } from "@/hooks/use-my-community";
import { formatCommunityTime } from "@/services/community-utils";
import { createThemedStyles, useAppTheme } from "@/theme/app-theme";

type MyCommunityTab = "published" | "participated" | "favorites";

const MY_COMMUNITY_TAB_OPTIONS: readonly NativeSegmentedControlOption<MyCommunityTab>[] =
  [
    { label: "Published", value: "published" },
    { label: "Participated", value: "participated" },
    { label: "Favorites", value: "favorites" },
  ];

export function MyCommunityScreen() {
  const styles = useMyCommunityStyles();
  const { colors } = useAppTheme();
  const [tab, setTab] = useState<MyCommunityTab>("published");
  const { error, load, loading, overview, refresh, refreshing } =
    useMyCommunity();

  const threads =
    tab === "published"
      ? (overview?.publishedThreads ?? [])
      : (overview?.favoriteThreads ?? []);
  const replies = overview?.participatedReplies ?? [];

  return (
    <CommunityPaperProvider>
      <NativeScreenScaffold
        largeTitle={false}
        onBackPress={() => router.back()}
        showBackButton
        title="My Community"
      >
        <ScrollView
          alwaysBounceVertical
          contentContainerStyle={styles.content}
          contentInsetAdjustmentBehavior="automatic"
          nestedScrollEnabled={process.env.EXPO_OS === "android"}
          refreshControl={
            <RefreshControl
              colors={[colors.accent as string]}
              onRefresh={() => void refresh()}
              refreshing={refreshing}
              tintColor={colors.accent as string}
            />
          }
          showsVerticalScrollIndicator={false}
          style={styles.root}
        >
          {overview ? (
            <Card mode="outlined" style={styles.profileCard}>
              <Card.Content style={styles.profileBody}>
                <Text style={styles.title}>
                  {overview.authorName || "My Community"}
                </Text>
                <Text style={styles.summary}>
                  {overview.publishedThreads.length} published ·{" "}
                  {overview.participatedReplies.length} replies ·{" "}
                  {overview.favoriteThreads.length} favorites
                </Text>
              </Card.Content>
            </Card>
          ) : null}

          <View style={styles.segmented}>
            <NativeSegmentedControl<MyCommunityTab>
              enabled={!loading}
              onValueChange={setTab}
              options={MY_COMMUNITY_TAB_OPTIONS}
              selectedValue={tab}
            />
          </View>

          {loading && !overview ? (
            <View style={styles.list}>
              <CommunityThreadSkeleton />
              <CommunityThreadSkeleton />
              <CommunityThreadSkeleton />
            </View>
          ) : error && !overview ? (
            <CommunityErrorState
              description={error}
              onRetry={() => void load()}
              title="Unable to load My Community"
            />
          ) : tab === "participated" ? (
            replies.length === 0 ? (
              <CommunityEmptyState
                description="Replies you publish in Community discussions will appear here."
                title="No participated discussions"
              />
            ) : (
              <View style={styles.list}>
                {replies.map((reply) => (
                  <MyReplyCard key={reply.id} reply={reply} />
                ))}
              </View>
            )
          ) : threads.length === 0 ? (
            <CommunityEmptyState
              description={
                tab === "published"
                  ? "Discussions you publish will appear here."
                  : "Discussions you favorite will appear here."
              }
              title={
                tab === "published"
                  ? "No published discussions"
                  : "No favorites"
              }
            />
          ) : (
            <View style={styles.list}>
              {threads.map((thread) => (
                <MyThreadCard key={thread.id} thread={thread} />
              ))}
            </View>
          )}
        </ScrollView>
      </NativeScreenScaffold>
    </CommunityPaperProvider>
  );
}

function MyThreadCard({ thread }: { thread: CommunityFeedItem }) {
  return (
    <CommunityThreadCard
      item={thread}
      onPress={() =>
        router.push({
          pathname: "/thread/[id]",
          params: { id: String(thread.id), initialTitle: thread.title },
        })
      }
    />
  );
}

function MyReplyCard({ reply }: { reply: CommunityMyReplyItem }) {
  const styles = useMyCommunityStyles();
  return (
    <Pressable
      accessibilityLabel={`Open ${reply.threadTitle}, reply: ${reply.content}`}
      accessibilityRole="button"
      onPress={() =>
        router.push({
          pathname: "/thread/[id]",
          params: {
            id: String(reply.threadId),
            initialTitle: reply.threadTitle,
            replyId: String(reply.id),
          },
        })
      }
      style={({ pressed }) => pressed && styles.pressed}
    >
      <Card mode="outlined" style={styles.replyCard}>
        <Card.Content style={styles.replyBody}>
          <View style={styles.replyHeader}>
            <Chip
              compact
              mode="flat"
              style={styles.boardChip}
              textStyle={styles.boardChipText}
            >
              {reply.boardName}
            </Chip>
            <Text style={styles.time}>
              {formatCommunityTime(reply.publishedAt)}
            </Text>
          </View>
          <Text numberOfLines={2} style={styles.replyTitle}>
            {reply.threadTitle}
          </Text>
          {reply.replyToName ? (
            <Text style={styles.replyTo}>Replying to {reply.replyToName}</Text>
          ) : null}
          <Text numberOfLines={4} style={styles.replyContent}>
            {reply.content}
          </Text>
          <View style={styles.replyMetrics}>
            <IconMessageCircle color={styles.metricIcon.color} size={15} />
            <Text style={styles.metricLabel}>Open discussion</Text>
            <IconHeart color={styles.metricIcon.color} size={15} />
            <Text style={styles.metricLabel}>{reply.likes}</Text>
          </View>
        </Card.Content>
      </Card>
    </Pressable>
  );
}

const useMyCommunityStyles = createThemedStyles((colors) => ({
  boardChip: {
    backgroundColor: colors.primaryContainer,
    borderRadius: 999,
  },
  boardChipText: {
    color: colors.onPrimaryContainer,
    fontSize: 11,
    fontWeight: "700",
  },
  content: { gap: 16, paddingBottom: 44, paddingHorizontal: 12, paddingTop: 8 },
  list: { gap: 12 },
  metricIcon: { color: colors.secondaryLabel },
  metricLabel: { color: colors.secondaryLabel, fontSize: 12 },
  pressed: { opacity: 0.68 },
  profileBody: { gap: 5, padding: 17 },
  profileCard: {
    backgroundColor: colors.card,
    borderColor: colors.separator,
    borderCurve: "continuous",
    borderRadius: 20,
  },
  replyBody: { gap: 9, padding: 15 },
  replyCard: {
    backgroundColor: colors.card,
    borderColor: colors.separator,
    borderCurve: "continuous",
    borderRadius: 20,
  },
  replyContent: { color: colors.label, fontSize: 14, lineHeight: 21 },
  replyHeader: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
  },
  replyMetrics: { alignItems: "center", flexDirection: "row", gap: 5 },
  replyTitle: {
    color: colors.label,
    fontSize: 16,
    fontWeight: "700",
    lineHeight: 21,
  },
  replyTo: { color: colors.accent, fontSize: 12, fontWeight: "600" },
  root: { backgroundColor: colors.background, flex: 1 },
  segmented: { minHeight: 48, width: "100%" },
  summary: { color: colors.secondaryLabel, fontSize: 13 },
  time: { color: colors.secondaryLabel, fontSize: 12 },
  title: { color: colors.label, fontSize: 23, fontWeight: "800" },
}));
