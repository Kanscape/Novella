import assert from 'node:assert/strict';
import test from 'node:test';

import { resolveCommunityBoardIconKey } from './community-board-icon-keys.ts';

test('Community board icon resolves mapped Material icon names', () => {
  assert.equal(resolveCommunityBoardIconKey('forum', ''), 'messages');
  assert.equal(resolveCommunityBoardIconKey('mdi-campaign', ''), 'speakerphone');
  assert.equal(resolveCommunityBoardIconKey('bullhorn', ''), 'speakerphone');
  assert.equal(resolveCommunityBoardIconKey('  video  ', ''), 'video');
  assert.equal(resolveCommunityBoardIconKey('book-open-variant', ''), 'book');
  assert.equal(resolveCommunityBoardIconKey('gamepad-round-outline', ''), 'gamepad-2');
});

test('Community board icon falls back to keyword matching on the text', () => {
  assert.equal(resolveCommunityBoardIconKey('', '动画交流'), 'video');
  assert.equal(resolveCommunityBoardIconKey('', '漫画区'), 'photo');
  assert.equal(resolveCommunityBoardIconKey('', '游戏讨论'), 'gamepad-2');
  assert.equal(resolveCommunityBoardIconKey('', '轻小说'), 'book');
  assert.equal(resolveCommunityBoardIconKey('', '站务公告'), 'speakerphone');
  assert.equal(resolveCommunityBoardIconKey('', '社区闲聊'), 'messages');
});

test('Community board icon returns null for unresolvable input', () => {
  assert.equal(resolveCommunityBoardIconKey('', ''), null);
  assert.equal(resolveCommunityBoardIconKey('   ', '   '), null);
  assert.equal(resolveCommunityBoardIconKey('unknown-icon-xyz', 'unrelated'), null);
});
