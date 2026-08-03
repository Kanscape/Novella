/**
 * One-shot carrier for the footnote bottom sheet. The chapter HTML, book font
 * data URL and reader colors are too large / transient to pass through the
 * router params, so they travel via this module-level slot: the reader screen
 * presents a payload before pushing the route, and the sheet consumes it.
 */
export interface ReaderFootnotePayload {
  content: string;
  fontDataUrl?: string;
}

let pending: ReaderFootnotePayload | null = null;

export function presentReaderFootnote(payload: ReaderFootnotePayload): void {
  pending = payload;
}

export function consumeReaderFootnote(): ReaderFootnotePayload | null {
  const payload = pending;
  pending = null;
  return payload;
}
