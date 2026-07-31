import {
  ApiClient,
  ApiError,
  type AnnouncementPage,
  type BookDetail,
  type BookListItem,
  type BookListPage,
  type CommentPage,
  type GetCommentsRequest,
  type NovelContent,
  type NovelContentRequest,
  type OnlineInfo,
  type PostCommentRequest,
  type ShelfItem,
} from '@novella/api-client';
import type {
  AppLifecycle,
  Clock,
  CredentialStore,
  HttpTransport,
  KeyValueStore,
  Logger,
  PasswordHasher,
  SignalRTransport,
} from '@novella/platform-contracts';
import type { SyncCrypto } from '@novella/sync';
import { Telemetry, type TelemetrySink } from '@novella/telemetry';

export const APP_DISPLAY_NAME = 'Novella';

export const AUTH_CREDENTIAL_KEYS = Object.freeze({
  refreshToken: 'novella.refresh-token',
  sessionToken: 'novella.session-token',
});

export interface ClientRuntimeDependencies {
  clock: Clock;
  credentials: CredentialStore;
  http: HttpTransport;
  signalR: SignalRTransport;
  lifecycle: AppLifecycle;
  logger: Logger;
  storage: KeyValueStore;
  syncCrypto: SyncCrypto;
  telemetry: TelemetrySink;
}

export interface ClientRuntime {
  api: ApiClient;
  dependencies: Readonly<ClientRuntimeDependencies>;
  telemetry: Telemetry;
}

export interface DiscoverySnapshot {
  announcements: AnnouncementPage;
  latestBooks: BookListPage;
  onlineInfo: OnlineInfo;
}

export interface DiscoveryUseCase {
  load(): Promise<DiscoverySnapshot>;
}

export interface BookDetailUseCase {
  load(bookId: number): Promise<BookDetail>;
}

export interface ReaderUseCase {
  loadChapter(request: NovelContentRequest): Promise<NovelContent>;
}

export interface CommentsUseCase {
  delete(commentId: number): Promise<void>;
  load(request: GetCommentsRequest): Promise<CommentPage>;
  post(request: PostCommentRequest): Promise<void>;
  reply(request: PostCommentRequest): Promise<void>;
}

export interface ShelfSnapshot {
  items: ShelfItem[];
  books: BookListItem[];
  version: string | null;
}

export interface ShelfUseCase {
  contains(bookId: number): Promise<boolean>;
  load(): Promise<ShelfSnapshot>;
  toggleBook(bookId: number): Promise<boolean>;
}

export interface AuthenticationUseCase {
  bootstrap(): Promise<void>;
  getSnapshot(): AuthenticationSnapshot;
  refresh(): Promise<boolean>;
  register(input: RegistrationInput): Promise<void>;
  resetPassword(input: PasswordResetInput): Promise<void>;
  sendRegisterCode(email: string): Promise<void>;
  sendResetCode(email: string): Promise<void>;
  signIn(email: string, password: string): Promise<void>;
  signOut(): Promise<void>;
  subscribe(listener: (snapshot: AuthenticationSnapshot) => void): () => void;
}

export interface RegistrationInput {
  userName: string;
  email: string;
  password: string;
  passwordConfirmation: string;
  code: string;
  inviteCode: string;
}

export interface PasswordResetInput {
  email: string;
  password: string;
  passwordConfirmation: string;
  code: string;
}

export type AuthenticationStatus =
  | 'unknown'
  | 'refreshing'
  | 'signingIn'
  | 'registering'
  | 'authenticated'
  | 'signedOut'
  | 'signingOut';

export interface AuthenticationSnapshot {
  status: AuthenticationStatus;
  error: string | null;
}

export function createClientRuntime(
  dependencies: ClientRuntimeDependencies,
): ClientRuntime {
  return Object.freeze({
    api: new ApiClient(dependencies.http, dependencies.signalR),
    dependencies: Object.freeze(dependencies),
    telemetry: new Telemetry(dependencies.telemetry),
  });
}

export function createDiscoveryUseCase(api: ApiClient): DiscoveryUseCase {
  return Object.freeze({
    async load() {
      const [latestBooks, announcements, onlineInfo] = await Promise.all([
        api.getLatestBookList({ size: 6 }),
        api.getAnnouncementList({ page: 1, size: 5 }),
        api.getOnlineInfo(),
      ]);
      return { announcements, latestBooks, onlineInfo };
    },
  });
}

export function createBookDetailUseCase(api: ApiClient): BookDetailUseCase {
  return Object.freeze({
    load(bookId: number) {
      if (!Number.isInteger(bookId) || bookId <= 0) {
        return Promise.reject(new Error('A valid book id is required.'));
      }
      return api.getBookInfo(bookId);
    },
  });
}

export function createReaderUseCase(api: ApiClient): ReaderUseCase {
  return Object.freeze({
    loadChapter(request: NovelContentRequest) {
      assertValidBookId(request.bookId);
      assertPositiveInteger(request.sortNum, 'A valid chapter number is required.');
      return api.getNovelContent(request);
    },
  });
}

export function createCommentsUseCase(api: ApiClient): CommentsUseCase {
  return Object.freeze({
    delete(commentId: number) {
      assertPositiveInteger(commentId, 'A valid comment id is required.');
      return api.deleteComment(commentId);
    },
    load(request: GetCommentsRequest) {
      assertPositiveInteger(request.id, 'A valid comment target id is required.');
      assertPositiveInteger(request.page, 'A valid comment page is required.');
      return api.getComments(request);
    },
    post(request: PostCommentRequest) {
      assertCommentRequest(request);
      return api.postComment(request);
    },
    reply(request: PostCommentRequest) {
      assertCommentRequest(request);
      if (request.parentId === undefined) {
        return Promise.reject(new Error('A parent comment is required for a reply.'));
      }
      return api.replyComment(request);
    },
  });
}

export function createShelfUseCase(api: ApiClient): ShelfUseCase {
  return Object.freeze({
    async contains(bookId: number) {
      assertValidBookId(bookId);
      const shelf = await api.getBookShelf();
      return shelf.items.some((item) => item.type === 'BOOK' && item.id === bookId);
    },
    async load() {
      const shelf = await api.getBookShelf();
      const bookIds = shelf.items
        .filter((item): item is Extract<ShelfItem, { type: 'BOOK' }> => item.type === 'BOOK')
        .map((item) => item.id);
      const books = [] as BookListItem[];
      for (let index = 0; index < bookIds.length; index += 24) {
        books.push(...(await api.getBookListByIds(bookIds.slice(index, index + 24))));
      }
      return {
        books,
        items: sortShelfItems(shelf.items),
        version: shelf.version,
      };
    },
    async toggleBook(bookId: number) {
      assertValidBookId(bookId);
      const shelf = await api.getBookShelf();
      const isInShelf = shelf.items.some(
        (item) => item.type === 'BOOK' && item.id === bookId,
      );
      const items = isInShelf
        ? shelf.items.filter((item) => item.type !== 'BOOK' || item.id !== bookId)
        : [
            {
              id: bookId,
              index: -1,
              parents: [],
              type: 'BOOK' as const,
              updatedAt: new Date().toISOString(),
            },
            ...shelf.items,
          ];
      await api.saveBookShelf({
        items: normalizeShelfIndexes(items),
        version: shelf.version,
      });
      return !isInShelf;
    },
  });
}

function assertValidBookId(bookId: number): void {
  if (!Number.isInteger(bookId) || bookId <= 0) {
    throw new Error('A valid book id is required.');
  }
}

function assertPositiveInteger(value: number, message: string): void {
  if (!Number.isInteger(value) || value <= 0) throw new Error(message);
}

function assertCommentRequest(request: PostCommentRequest): void {
  assertPositiveInteger(request.id, 'A valid comment target id is required.');
  if (!request.content.trim()) throw new Error('Comment content is required.');
}

function normalizeShelfIndexes(items: ShelfItem[]): ShelfItem[] {
  const nextIndexByParents = new Map<string, number>();
  return sortShelfItems(items).map((item) => {
    const parentKey = JSON.stringify(item.parents);
    const index = nextIndexByParents.get(parentKey) ?? 0;
    nextIndexByParents.set(parentKey, index + 1);
    return { ...item, index };
  });
}

function sortShelfItems(items: ShelfItem[]): ShelfItem[] {
  return [...items].sort((a, b) => {
    if (a.index !== b.index) return a.index - b.index;
    return a.parents.length - b.parents.length;
  });
}

export function createAuthenticationUseCase(
  api: ApiClient,
  passwordHasher: PasswordHasher,
  credentials: CredentialStore,
  signalR: SignalRTransport,
): AuthenticationUseCase {
  let revision = 0;
  let snapshot: AuthenticationSnapshot = { status: 'unknown', error: null };
  let refreshInFlight: {
    revision: number;
    refreshToken: string;
    promise: Promise<boolean>;
  } | null = null;
  let credentialWrite = Promise.resolve();
  const listeners = new Set<(next: AuthenticationSnapshot) => void>();

  function publish(next: AuthenticationSnapshot): void {
    snapshot = next;
    for (const listener of listeners) listener(snapshot);
  }

  function enqueueCredentialWrite<T>(operation: () => Promise<T>): Promise<T> {
    const next = credentialWrite.then(operation, operation);
    credentialWrite = next.then(
      () => undefined,
      () => undefined,
    );
    return next;
  }

  async function persistTokens(
    tokens: { sessionToken: string; refreshToken: string },
    expectedRevision: number,
  ): Promise<boolean> {
    return enqueueCredentialWrite(async () => {
      if (expectedRevision !== revision) return false;
      await credentials.set(AUTH_CREDENTIAL_KEYS.refreshToken, tokens.refreshToken);
      if (expectedRevision !== revision) return false;
      await credentials.set(AUTH_CREDENTIAL_KEYS.sessionToken, tokens.sessionToken);
      return expectedRevision === revision;
    });
  }

  async function clearCredentials(expectedRevision: number): Promise<void> {
    await enqueueCredentialWrite(async () => {
      if (expectedRevision !== revision) return;
      await credentials.delete(AUTH_CREDENTIAL_KEYS.sessionToken);
      await credentials.delete(AUTH_CREDENTIAL_KEYS.refreshToken);
    });
  }

  async function performRefresh(
    expectedRevision: number,
    refreshToken: string,
  ): Promise<boolean> {
    try {
      const sessionToken = await api.refreshToken(refreshToken);
      const persisted = await enqueueCredentialWrite(async () => {
        if (expectedRevision !== revision) return false;
        await credentials.set(AUTH_CREDENTIAL_KEYS.sessionToken, sessionToken);
        return expectedRevision === revision;
      });
      if (!persisted) return false;
      revision += 1;
      publish({ status: 'authenticated', error: null });
      await signalR.close();
      return true;
    } catch (error) {
      if (expectedRevision !== revision) return false;
      if (isInvalidRefreshError(error)) {
        revision += 1;
        await clearCredentials(revision);
        publish({ status: 'signedOut', error: null });
        return false;
      }
      publish({
        status: 'signedOut',
        error: error instanceof Error ? error.message : 'Unable to restore your session.',
      });
      return false;
    }
  }

  async function refresh(): Promise<boolean> {
    const expectedRevision = revision;
    const refreshToken = await credentials.get(AUTH_CREDENTIAL_KEYS.refreshToken);
    if (expectedRevision !== revision) return false;
    if (!refreshToken) {
      publish({ status: 'signedOut', error: null });
      return false;
    }

    const shared = refreshInFlight;
    if (
      shared &&
      shared.revision === expectedRevision &&
      shared.refreshToken === refreshToken
    ) {
      return shared.promise;
    }

    publish({ status: 'refreshing', error: null });
    const promise = performRefresh(expectedRevision, refreshToken);
    refreshInFlight = { revision: expectedRevision, refreshToken, promise };
    try {
      return await promise;
    } finally {
      if (refreshInFlight?.promise === promise) refreshInFlight = null;
    }
  }

  async function bootstrap(): Promise<void> {
    if (snapshot.status === 'authenticated' || snapshot.status === 'refreshing') return;
    await refresh();
  }

  async function signIn(email: string, password: string) {
    const normalizedEmail = normalizeAndValidateEmail(email);
    if (!password) throw new Error('Enter your password.');
    const expectedRevision = ++revision;
    publish({ status: 'signingIn', error: null });
    try {
      await clearCredentials(expectedRevision);
      const passwordHash = await passwordHasher.sha256(password);
      const tokens = await api.login({
        email: normalizedEmail,
        passwordHash,
      });
      if (!(await persistTokens(tokens, expectedRevision))) {
        throw new Error('Sign in was cancelled.');
      }
      publish({ status: 'authenticated', error: null });
      await signalR.close();
    } catch (error) {
      if (expectedRevision === revision) {
        publish({
          status: 'signedOut',
          error: error instanceof Error ? error.message : 'Unable to sign in.',
        });
      }
      throw error;
    }
  }

  async function register(input: RegistrationInput): Promise<void> {
    const userName = input.userName.trim();
    const email = normalizeEmail(input.email);
    const code = input.code.trim();
    if (!userName) throw new Error('Enter a username.');
    assertEmail(email);
    assertPassword(input.password, input.passwordConfirmation);
    if (!code) throw new Error('Enter the verification code.');

    const expectedRevision = ++revision;
    publish({ status: 'registering', error: null });
    try {
      await clearCredentials(expectedRevision);
      const passwordHash = await passwordHasher.sha256(input.password);
      const tokens = await api.register({
        userName,
        email,
        passwordHash,
        code,
        inviteCode: input.inviteCode.trim(),
      });
      if (!(await persistTokens(tokens, expectedRevision))) {
        throw new Error('Registration was cancelled.');
      }
      publish({ status: 'authenticated', error: null });
      await signalR.close();
    } catch (error) {
      if (expectedRevision === revision) {
        publish({
          status: 'signedOut',
          error: error instanceof Error ? error.message : 'Unable to create your account.',
        });
      }
      throw error;
    }
  }

  async function sendRegisterCode(email: string): Promise<void> {
    await api.sendRegisterEmail(normalizeAndValidateEmail(email));
  }

  async function sendResetCode(email: string): Promise<void> {
    await api.sendResetEmail(normalizeAndValidateEmail(email));
  }

  async function resetPassword(input: PasswordResetInput): Promise<void> {
    const email = normalizeAndValidateEmail(input.email);
    const code = input.code.trim();
    assertPassword(input.password, input.passwordConfirmation);
    if (!code) throw new Error('Enter the verification code.');
    const passwordHash = await passwordHasher.sha256(input.password);
    await api.resetPassword({
      email,
      newPasswordHash: passwordHash,
      code,
    });
  }

  async function signOut(): Promise<void> {
    const expectedRevision = ++revision;
    publish({ status: 'signingOut', error: null });
    await clearCredentials(expectedRevision);
    await signalR.close();
    publish({ status: 'signedOut', error: null });
  }

  return Object.freeze({
    bootstrap,
    getSnapshot: () => snapshot,
    register,
    resetPassword,
    refresh,
    sendRegisterCode,
    sendResetCode,
    signIn,
    signOut,
    subscribe(listener: (next: AuthenticationSnapshot) => void) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
  });
}

function isInvalidRefreshError(error: unknown): boolean {
  return (
    error instanceof ApiError &&
    error.category === 'auth' &&
    (error.status === 401 || error.status === 404 || error.status === -100)
  );
}

const EMAIL_PATTERN = /^\w+([-+.]\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$/i;

function normalizeEmail(email: string): string {
  return email.trim();
}

function normalizeAndValidateEmail(email: string): string {
  const normalized = normalizeEmail(email);
  assertEmail(normalized);
  return normalized;
}

function assertEmail(email: string): void {
  if (!EMAIL_PATTERN.test(email)) throw new Error('Enter a valid email address.');
}

function assertPassword(password: string, confirmation: string): void {
  if (password.length < 8) throw new Error('Password must be at least 8 characters.');
  if (password !== confirmation) throw new Error('Passwords do not match.');
}
