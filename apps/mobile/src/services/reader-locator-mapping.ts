import type { NovelReaderBlock } from '@novella/reader-engine';

import { chapterHrefFor } from '@/services/reader-rwpm';

const MAX_ANCHOR_LENGTH = 80;

function stripHtmlToText(html: string): string {
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;|&#160;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;|&apos;/gi, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function blockTexts(blocks: readonly NovelReaderBlock[]): string[] {
  return blocks.map((block) => stripHtmlToText(block.html));
}

/** Finds the block whose text contains the longest suffix of `anchor`. */
function findBlockForAnchor(
  blocks: readonly NovelReaderBlock[],
  anchor: string,
): number {
  const needle = anchor.trim();
  if (!needle) return -1;
  const suffix = needle.length > MAX_ANCHOR_LENGTH
    ? needle.slice(-MAX_ANCHOR_LENGTH)
    : needle;
  const texts = blockTexts(blocks);
  let bestIndex = -1;
  let bestScore = -1;
  for (let index = 0; index < texts.length; index += 1) {
    const text = texts[index];
    if (!text) continue;
    if (text.includes(suffix)) {
      bestIndex = index;
      bestScore = suffix.length;
      break;
    }
    // Tolerate small punctuation drift at the anchor edges.
    const compactNeedle = suffix.replace(/[^\p{L}\p{N}]/gu, '');
    if (compactNeedle.length >= 12) {
      const compactText = text.replace(/[^\p{L}\p{N}]/gu, '');
      if (compactText.includes(compactNeedle)) {
        bestIndex = index;
        bestScore = compactNeedle.length;
        break;
      }
    }
  }
  return bestIndex;
}

/**
 * Maps a chapter scroll position (0-1 progression + visible-text anchor)
 * reported by the WebView back to the Novella server position format
 * ({ chapterId, position: block locator }). The anchor is matched against the
 * block texts; when it does not match, the progression is used as a fallback.
 */
export function readerPositionToBlock(
  progression: number,
  anchor: string | undefined,
  chapterId: number,
  blocks: readonly NovelReaderBlock[],
): { chapterId: number; position: string } | null {
  if (blocks.length === 0) return null;

  const blockIndex = anchor
    ? findBlockForAnchor(blocks, anchor)
    : -1;
  const resolved = blockIndex >= 0
    ? blockIndex
    : Math.floor(Math.max(0, Math.min(1, progression)) * blocks.length);

  const clamped = Math.max(0, Math.min(resolved, blocks.length - 1));
  const block = blocks[clamped];
  if (!block) return null;
  return { chapterId, position: block.locator };
}

/**
 * Maps a Novella server position (block locator) to a 0-1 scroll progression.
 * Progression is approximated by the block's text offset over the chapter's
 * total text length.
 */
export function readerPositionToProgression(
  position: string | null | undefined,
  chapterId: number,
  blocks: readonly NovelReaderBlock[],
): number {
  if (blocks.length === 0) return 0;

  if (!position) return 0;

  let index = blocks.findIndex((block) => block.locator === position);
  if (index < 0) {
    // Fall back to prefix matching (parent node paths) like the old renderer.
    let candidate = position;
    while (candidate.length > 0) {
      const slash = candidate.lastIndexOf('/');
      if (slash <= 0) break;
      candidate = candidate.slice(0, slash);
      index = blocks.findIndex((block) => block.locator === candidate);
      if (index >= 0) break;
    }
  }
  if (index < 0) return 0;

  const texts = blockTexts(blocks);
  let offset = 0;
  let total = 0;
  for (let blockIndex = 0; blockIndex < texts.length; blockIndex += 1) {
    const length = Math.max(1, (texts[blockIndex] ?? '').length);
    if (blockIndex < index) offset += length;
    total += length;
  }
  offset += Math.floor((texts[index] ?? '').length / 2);
  return Math.min(1, Math.max(0, offset / total));
}

/** Kept for callers that need the chapter href (used as a stable key). */
export function chapterHrefForChapter(chapterId: number): string {
  return chapterHrefFor(chapterId);
}
