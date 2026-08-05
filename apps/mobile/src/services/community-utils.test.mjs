import assert from 'node:assert/strict';
import test from 'node:test';

import {
  findCommunityReply,
  formatCommunityCount,
  formatCommunityTime,
  mergeCommunityItems,
  notificationTargetParams,
  updateCommunityReply,
} from './community-utils.ts';

test('Community pagination append keeps order and removes duplicate ids', () => {
  assert.deepEqual(
    mergeCommunityItems([{ id: 1 }, { id: 2 }], [{ id: 2 }, { id: 3 }]),
    [{ id: 1 }, { id: 2 }, { id: 3 }],
  );
});

test('Community nested reply helpers find and update a child reply', () => {
  const replies = [{
    id: 1,
    childReplies: [{ id: 2, childReplies: [], likes: 1 }],
    likes: 0,
  }];
  assert.equal(findCommunityReply(replies, 2).likes, 1);
  const updated = updateCommunityReply(replies, 2, (reply) => ({ ...reply, likes: 5 }));
  assert.equal(findCommunityReply(updated, 2).likes, 5);
  assert.equal(findCommunityReply(updated, 99), null);
});

test('Community notification target prefers decoded Extra ids', () => {
  assert.deepEqual(notificationTargetParams({
    objectId: 4,
    extra: { objectId: 9, replyId: 11, parentReplyId: 10 },
  }), {
    id: 9,
    replyId: 11,
    parentReplyId: 10,
  });
});

test('Community relative time handles recent and missing values', () => {
  const originalNow = Date.now;
  Date.now = () => Date.parse('2026-08-04T12:00:00.000Z');
  try {
    assert.equal(formatCommunityTime(null), '');
    assert.equal(formatCommunityTime('2026-08-04T11:59:40.000Z'), 'just now');
    assert.equal(formatCommunityTime('2026-08-04T11:55:00.000Z'), '5 minutes ago');
    assert.equal(formatCommunityTime('2026-08-04T10:00:00.000Z'), '2 hours ago');
  } finally {
    Date.now = originalNow;
  }
});

test('Community compact count formats thousands and above', () => {
  assert.equal(formatCommunityCount(0), '0');
  assert.equal(formatCommunityCount(999), '999');
  assert.equal(formatCommunityCount(1000), '1k');
  assert.equal(formatCommunityCount(1234), '1.2k');
  assert.equal(formatCommunityCount(9999), '10k');
  assert.equal(formatCommunityCount(10000), '1万');
  assert.equal(formatCommunityCount(12400), '1.2万');
  assert.equal(formatCommunityCount(100000), '10万');
  assert.equal(formatCommunityCount(1200000), '1.2M');
});
