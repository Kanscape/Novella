import { Asset } from 'expo-asset';
import * as FileSystem from 'expo-file-system';
import * as Font from 'expo-font';

import { SERVICE_ENDPOINTS } from '@novella/api-client';
import {
  convertWoff2ToTtf,
  extractInvisibleCodepoints,
} from '../../modules/novella-rs';

const readerFontCache = new Map<string, Promise<string>>();
const readerFontCacheDirectory = new FileSystem.Directory(
  FileSystem.Paths.cache,
  'novella-reader-fonts',
);
const readerInvisibleCodepoints = new Map<string, ReadonlySet<number>>();

/**
 * Registers a Web-Master chapter font with native text rendering.
 *
 * Web-Master serves obfuscated WOFF2 files. The shared Rust implementation
 * converts them to TTF before Expo Font registration so Android and iOS use
 * the same format. A failed conversion/download blocks encoded chapter text
 * instead of rendering misleading replacement glyphs.
 */
export function loadReaderFont(family: string, fontUrl: string): Promise<string> {
  const cached = readerFontCache.get(fontUrl);
  if (cached) return cached;

  const pending = loadReaderFontInternal(family, fontUrl).catch((error: unknown) => {
    readerFontCache.delete(fontUrl);
    console.info('[ReaderFont] failed', {
      family,
      url: fontUrl,
      error: error instanceof Error ? error.message : String(error),
    });
    throw error;
  });
  readerFontCache.set(fontUrl, pending);
  return pending;
}

export function resolveReaderFontUrl(fontUrl: string | null | undefined): string | null {
  if (!fontUrl || !fontUrl.trim()) return null;
  const value = fontUrl.trim();
  return value.startsWith('http://') || value.startsWith('https://')
    ? value
    : `${SERVICE_ENDPOINTS.apiOrigin}${value.startsWith('/') ? value : `/${value}`}`;
}

export function readerFontFamilyForUrl(url: string): string {
  return `NovellaReaderFont_${hashFontUrl(url)}`;
}

export function invisibleCodepointsForReaderFont(family: string): ReadonlySet<number> {
  return readerInvisibleCodepoints.get(family) ?? new Set<number>();
}

export function clearReaderFontCache(): number {
  readerFontCache.clear();
  readerInvisibleCodepoints.clear();
  if (!readerFontCacheDirectory.exists) return 0;

  const entryCount = readerFontCacheDirectory.list().length;
  readerFontCacheDirectory.delete();
  return entryCount;
}

async function loadReaderFontInternal(family: string, url: string): Promise<string> {
  console.info('[ReaderFont] loading', { family, url });
  const fontFile = await getCachedFontFile(url);
  // Mark the already-downloaded file as an Expo Asset so expo-font uses its
  // file:// URI instead of attempting a second remote download.
  const asset = Asset.fromURI(fontFile.uri);
  asset.localUri = fontFile.uri;
  asset.downloaded = true;
  await Font.loadAsync(family, asset);
  if (!Font.isLoaded(family)) {
    throw new Error(`Expo Font did not register ${family}`);
  }
  const ttfBytes = fontFile.bytesSync();
  const invisible = await extractInvisibleCodepoints(ttfBytes);
  readerInvisibleCodepoints.set(family, new Set(invisible));
  console.info('[ReaderFont] extracted invisible codepoints', {
    family,
    count: invisible.length,
  });
  console.info('[ReaderFont] registered', { family, uri: fontFile.uri });
  return family;
}

async function getCachedFontFile(url: string): Promise<FileSystem.File> {
  ensureCacheDirectory();

  const cacheKey = hashFontUrl(url);
  const ttfFile = new FileSystem.File(readerFontCacheDirectory, `${cacheKey}.ttf`);
  if (ttfFile.exists && isTtfFile(ttfFile)) {
    console.info('[ReaderFont] using cached TTF', { uri: ttfFile.uri });
    return ttfFile;
  }
  if (ttfFile.exists) ttfFile.delete();

  console.info('[ReaderFont] downloading WOFF2', { url });
  const woff2File = await downloadFont(url, `${cacheKey}.woff2`);
  try {
    const woff2Bytes = woff2File.bytesSync();
    if (!isWoff2Bytes(woff2Bytes)) throw new Error('Reader font is not a WOFF2 file');
    console.info('[ReaderFont] downloaded WOFF2', { bytes: woff2Bytes.byteLength });
    const ttfBytes = await convertWoff2ToTtf(woff2Bytes);
    if (!isTtfBytes(ttfBytes)) throw new Error('Rust WOFF2 conversion returned invalid TTF');
    ttfFile.write(ttfBytes);
    console.info('[ReaderFont] converted WOFF2 to TTF', { bytes: ttfBytes.byteLength });
    return ttfFile;
  } finally {
    if (woff2File.exists) woff2File.delete();
  }
}

function ensureCacheDirectory(): void {
  if (!readerFontCacheDirectory.exists) {
    readerFontCacheDirectory.create({ intermediates: true });
  }
}

async function downloadFont(url: string, fileName: string): Promise<FileSystem.File> {
  const destination = new FileSystem.File(readerFontCacheDirectory, fileName);
  if (destination.exists && (destination.size ?? 0) > 0) return destination;
  return FileSystem.File.downloadFileAsync(url, destination, { idempotent: true });
}

function readUint32(bytes: Uint8Array, offset: number): number {
  return (
    ((bytes[offset] ?? 0) << 24) |
    ((bytes[offset + 1] ?? 0) << 16) |
    ((bytes[offset + 2] ?? 0) << 8) |
    (bytes[offset + 3] ?? 0)
  ) >>> 0;
}

function isTtfFile(file: FileSystem.File): boolean {
  if (!file.exists || (file.size ?? 0) < 4) return false;
  return isTtfBytes(file.bytesSync());
}

function isTtfBytes(bytes: Uint8Array): boolean {
  if (bytes.byteLength < 4) return false;
  const signature = readUint32(bytes, 0);
  return signature === 0x00010000 || signature === 0x4f54544f;
}

function isWoff2Bytes(bytes: Uint8Array): boolean {
  return bytes.byteLength >= 4 && readUint32(bytes, 0) === 0x774f4632;
}

function hashFontUrl(value: string): string {
  let hash = 2166136261;
  for (const character of value) {
    hash ^= character.codePointAt(0) ?? 0;
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(36);
}
