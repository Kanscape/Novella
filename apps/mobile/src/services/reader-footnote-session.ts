export interface ReaderFootnoteSession {
  bookId: number;
  fontFamily?: string;
  fontSize: number;
  html: string;
  lineHeight: number;
}

const sessions = new Map<string, ReaderFootnoteSession>();
let nextSessionId = 0;

export function createReaderFootnoteSession(
  session: ReaderFootnoteSession,
): string {
  nextSessionId += 1;
  const token = `${Date.now().toString(36)}-${nextSessionId.toString(36)}`;
  sessions.set(token, session);
  return token;
}

export function getReaderFootnoteSession(
  token: string,
): ReaderFootnoteSession | undefined {
  return sessions.get(token);
}

export function releaseReaderFootnoteSession(token: string): void {
  sessions.delete(token);
}
