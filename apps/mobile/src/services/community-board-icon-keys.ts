/**
 * Pure board-icon name resolution, ported from the Flutter legacy
 * `resolveCommunityBoardIcon` / `resolveCommunityBoardFallbackIcon` pair.
 *
 * Returns a stable icon key (matching the @tabler/icons-react-native export
 * suffix) or null when neither the icon name nor the fallback text resolves.
 * This module must stay free of React Native imports so node can unit-test it.
 */
export function resolveCommunityBoardIconKey(
  rawName: string,
  fallbackText: string,
): string | null {
  const mapped = BOARD_ICON_KEYS[normalizeIconName(rawName)];
  if (mapped) return mapped;
  return fallbackBoardIconKey(fallbackText);
}

function normalizeIconName(rawName: string): string {
  const lower = rawName.trim().toLowerCase();
  const withoutPrefix = lower.startsWith('mdi') ? lower.slice(3) : lower;
  return withoutPrefix.replace(/[^a-z0-9]+/g, '');
}

const BOARD_ICON_KEYS: Readonly<Record<string, string>> = {
  forum: 'messages',
  forumoutline: 'messages',
  commentmultiple: 'messages',
  messageoutline: 'message-circle',
  bullhorn: 'speakerphone',
  campaign: 'speakerphone',
  web: 'language',
  video: 'video',
  movie: 'movie',
  playboxmultipleoutline: 'video',
  image: 'photo',
  imageoutline: 'photo',
  palette: 'palette',
  controller: 'gamepad-2',
  gamepadvariantoutline: 'gamepad-2',
  gamepadroundoutline: 'gamepad-2',
  book: 'book',
  bookopenvariant: 'book',
  textboxoutline: 'notes',
  star: 'star',
};

function fallbackBoardIconKey(fallbackText: string): string | null {
  const text = fallbackText.trim();
  if (text.length === 0) return null;

  if (containsAny(text, ['动画', '番剧', '视频'])) return 'video';
  if (containsAny(text, ['漫画', '插画', '画'])) return 'photo';
  if (containsAny(text, ['游戏'])) return 'gamepad-2';
  if (containsAny(text, ['小说', '轻小说', '书'])) return 'book';
  if (containsAny(text, ['站务', '公告', '反馈'])) return 'speakerphone';
  if (containsAny(text, ['全部', '讨论', '社区'])) return 'messages';

  return null;
}

function containsAny(text: string, keywords: readonly string[]): boolean {
  return keywords.some((keyword) => text.includes(keyword));
}
