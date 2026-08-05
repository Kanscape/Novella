import type {
  AppNotificationItem,
  CommunityFeedItem,
  CommunityThreadReply,
} from '@novella/api-client';

export function formatCommunityCount(value: number): string {
  if (value >= 1_000_000) {
    const compact = (value / 1_000_000).toFixed(1).replace(/\.0$/, '');
    return `${compact}M`;
  }
  if (value >= 10_000) {
    const compact = (value / 10_000).toFixed(1).replace(/\.0$/, '');
    return `${compact}万`;
  }
  if (value >= 1_000) {
    const compact = (value / 1_000).toFixed(1).replace(/\.0$/, '');
    return `${compact}k`;
  }
  return String(value);
}

export function formatCommunityTime(value: string | null): string {
  if (!value) return '';
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return '';
  const delta = Date.now() - timestamp;
  const future = delta < 0;
  const absolute = Math.abs(delta);
  const minute = 60_000;
  const hour = 60 * minute;
  const day = 24 * hour;
  const format = (count: number, unit: string) =>
    future ? `in ${count} ${unit}${count === 1 ? '' : 's'}` : `${count} ${unit}${count === 1 ? '' : 's'} ago`;
  if (absolute < minute) return 'just now';
  if (absolute < hour) return format(Math.floor(absolute / minute), 'minute');
  if (absolute < day) return format(Math.floor(absolute / hour), 'hour');
  if (absolute < 7 * day) return format(Math.floor(absolute / day), 'day');
  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(timestamp);
}

export function mergeCommunityItems<T extends { id: number }>(
  current: readonly T[],
  incoming: readonly T[],
): T[] {
  const seen = new Set(current.map((item) => item.id));
  return [...current, ...incoming.filter((item) => !seen.has(item.id))];
}

export function updateCommunityReply(
  replies: readonly CommunityThreadReply[],
  replyId: number,
  update: (reply: CommunityThreadReply) => CommunityThreadReply,
): CommunityThreadReply[] {
  return replies.map((reply) => {
    if (reply.id === replyId) return update(reply);
    const childReplies = updateCommunityReply(reply.childReplies, replyId, update);
    return childReplies === reply.childReplies ? reply : { ...reply, childReplies };
  });
}

export function findCommunityReply(
  replies: readonly CommunityThreadReply[],
  replyId: number,
): CommunityThreadReply | null {
  for (const reply of replies) {
    if (reply.id === replyId) return reply;
    const child = findCommunityReply(reply.childReplies, replyId);
    if (child) return child;
  }
  return null;
}

export function notificationTargetParams(notification: AppNotificationItem): {
  id: number;
  parentReplyId: number | null;
  replyId: number | null;
} {
  return {
    id: notification.extra.objectId || notification.objectId,
    parentReplyId: notification.extra.parentReplyId,
    replyId: notification.extra.replyId,
  };
}

export function threadAccessibilityLabel(item: CommunityFeedItem): string {
  const author = item.authorIsDeleted ? 'Deleted user' : item.authorName || 'Unknown author';
  const status = [
    item.pinned ? 'Pinned' : '',
    item.featured ? 'Featured' : '',
    item.locked ? 'Locked' : '',
  ].filter(Boolean).join(', ');
  const statusPart = status ? `, ${status}` : '';
  return `${item.title}, ${item.boardName}, by ${author}, ${item.replies} replies, ${item.views} views${statusPart}`;
}
