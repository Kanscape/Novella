export type ReaderImageExtension =
  | '.jpg'
  | '.png'
  | '.webp'
  | '.gif'
  | '.bmp'
  | '.heic'
  | '.heif';

export interface ReaderImageFormat {
  extension: ReaderImageExtension;
  mimeType: string;
  uti: string;
}

const READER_IMAGE_FORMATS: Record<ReaderImageExtension, ReaderImageFormat> = {
  '.jpg': { extension: '.jpg', mimeType: 'image/jpeg', uti: 'public.jpeg' },
  '.png': { extension: '.png', mimeType: 'image/png', uti: 'public.png' },
  '.webp': { extension: '.webp', mimeType: 'image/webp', uti: 'org.webmproject.webp' },
  '.gif': { extension: '.gif', mimeType: 'image/gif', uti: 'com.compuserve.gif' },
  '.bmp': { extension: '.bmp', mimeType: 'image/bmp', uti: 'com.microsoft.bmp' },
  '.heic': { extension: '.heic', mimeType: 'image/heic', uti: 'public.heic' },
  '.heif': { extension: '.heif', mimeType: 'image/heif', uti: 'public.heif' },
};

const CONTENT_TYPE_TO_EXTENSION: Record<string, ReaderImageExtension> = {
  'image/jpeg': '.jpg',
  'image/jpg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'image/bmp': '.bmp',
  'image/heic': '.heic',
  'image/heif': '.heif',
};

/**
 * Resolve a file format the native share/gallery APIs can understand.
 * Content-Type wins over the URL, matching Flutter's download path. Unknown
 * formats intentionally fall back to JPEG because image endpoints commonly
 * omit both a useful extension and a content type.
 */
export function resolveReaderImageFormat(
  imageUrl: string,
  contentType?: string | null,
): ReaderImageFormat {
  const contentTypeExtension = extensionFromContentType(contentType);
  if (contentTypeExtension) return READER_IMAGE_FORMATS[contentTypeExtension];

  const urlExtension = extensionFromUrl(imageUrl);
  if (urlExtension) return READER_IMAGE_FORMATS[urlExtension];

  return READER_IMAGE_FORMATS['.jpg'];
}

function extensionFromContentType(contentType: string | null | undefined): ReaderImageExtension | null {
  if (!contentType) return null;
  const normalized = contentType.split(';', 1)[0]?.trim().toLowerCase();
  return normalized ? CONTENT_TYPE_TO_EXTENSION[normalized] ?? null : null;
}

function extensionFromUrl(imageUrl: string): ReaderImageExtension | null {
  let pathname = imageUrl;
  try {
    pathname = new URL(imageUrl).pathname;
  } catch {
    // Relative or otherwise unusual URLs are still handled by the suffix
    // fallback below.
  }

  const rawExtension = pathname.match(/(\.[a-z0-9]+)$/iu)?.[1]?.toLowerCase();
  if (!rawExtension) return null;
  return isReaderImageExtension(rawExtension) ? rawExtension : null;
}

function isReaderImageExtension(value: string): value is ReaderImageExtension {
  return Object.prototype.hasOwnProperty.call(READER_IMAGE_FORMATS, value);
}
