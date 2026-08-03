import { normalizeBlurHash } from '@novella/api-client';

export interface ExpoBlurHashPlaceholder {
  blurhash: string;
  height: number;
  width: number;
}

export const BOOK_COVER_BLURHASH_SIZE = Object.freeze({ width: 32, height: 48 });
const MAX_COMIC_BLURHASH_DIMENSION = 48;

export function createBookCoverBlurHashPlaceholder(
  value: string | null | undefined,
): ExpoBlurHashPlaceholder | null {
  return createBlurHashPlaceholder(
    value,
    BOOK_COVER_BLURHASH_SIZE.width,
    BOOK_COVER_BLURHASH_SIZE.height,
  );
}

export function createComicBlurHashPlaceholder(
  value: string | null | undefined,
  naturalWidth: number,
  naturalHeight: number,
): ExpoBlurHashPlaceholder | null {
  const ratio = Math.max(0.05, naturalHeight / Math.max(1, naturalWidth));
  const width = ratio >= 1
    ? Math.max(1, Math.round(MAX_COMIC_BLURHASH_DIMENSION / ratio))
    : MAX_COMIC_BLURHASH_DIMENSION;
  const height = ratio >= 1
    ? MAX_COMIC_BLURHASH_DIMENSION
    : Math.max(1, Math.round(MAX_COMIC_BLURHASH_DIMENSION * ratio));
  return createBlurHashPlaceholder(value, width, height);
}

function createBlurHashPlaceholder(
  value: string | null | undefined,
  width: number,
  height: number,
): ExpoBlurHashPlaceholder | null {
  const blurhash = normalizeBlurHash(value);
  return blurhash ? { blurhash, width, height } : null;
}
