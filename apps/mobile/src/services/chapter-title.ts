/**
 * Chapter-title simplification (ported from the Flutter
 * `simplifyReaderChapterTitle`): drops the descriptive tail of a chapter
 * title, keeping only the leading number/name part.
 *
 * - "【第五章 觉醒】"            → "第五章 觉醒"   (bracket prefix wins)
 * - "第5章 觉醒"                → "第5章"        (prefix before a space)
 * - "第一章『觉醒』"            → "第一章"        (prefix before 『
 * - "Chapter 5 The Awakening"   → unchanged      (Latin word + space is kept)
 * - "觉醒" (no separator)       → unchanged
 */

const CLEAN_CHAPTER_TITLE_PATTERN =
  /^\s*(?:【([^】]*)】.*|(?![a-zA-Z]+\s)([^\s『「〈]+)[\s『「〈].*)$/;

export function simplifyReaderChapterTitle(title: string): string {
  const trimmed = title.trim();
  if (trimmed === '') return '';
  const match = CLEAN_CHAPTER_TITLE_PATTERN.exec(trimmed);
  if (match === null) return trimmed;
  const extracted = `${match[1] ?? ''}${match[2] ?? ''}`.trim();
  return extracted === '' ? trimmed : extracted;
}
