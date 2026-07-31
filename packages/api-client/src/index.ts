import type {
  HttpRequest,
  HttpResponse,
  HttpTransport,
  JsonValue,
  SignalRTransport,
} from '@novella/platform-contracts';
import { ungzip } from 'pako';

export const SERVICE_ENDPOINTS = Object.freeze({
  apiOrigin: 'https://api.lightnovel.life',
  loginPath: '/api/user/login',
  registerPath: '/api/user/register',
  sendRegisterEmailPath: '/api/user/send_register_email',
  sendResetEmailPath: '/api/user/send_reset_email',
  resetPasswordPath: '/api/user/reset_password',
  refreshTokenPath: '/api/user/refresh_token',
  signalRHub: 'https://api.lightnovel.life/hub/api',
});

export const SIGNALR_PROTOCOL = Object.freeze({
  name: 'messagepack',
  transferFormat: 'binary',
  version: 1,
});

export const SIGNALR_OPTIONS = Object.freeze({
  useGzip: true,
});

export const SHELF_STRUCT_VERSION = '20220211';

export interface ApiRequest extends Omit<HttpRequest, 'url'> {
  path: `/${string}`;
  query?: Readonly<Record<string, string>>;
}

export interface LoginRequest {
  email: string;
  passwordHash: string;
}

export interface RegisterRequest {
  userName: string;
  email: string;
  passwordHash: string;
  code: string;
  inviteCode: string;
}

export interface ResetPasswordRequest {
  email: string;
  newPasswordHash: string;
  code: string;
}

export interface SessionTokens {
  sessionToken: string;
  refreshToken: string;
}

export interface AuthRetryHandler {
  refresh(): Promise<boolean>;
}

export interface BookListItem {
  id: number;
  type: 'Novel' | 'Comic';
  title: string;
  seriesTitle: string | null;
  coverUrl: string;
  coverPlaceholder: string | null;
  authorName: string | null;
  lastUpdatedAt: string;
  level: number | null;
  interiorLevel: number | null;
  category: BookCategory | null;
}

export interface BookCategory {
  name: string;
  shortName: string;
  color: string;
}

export interface BookListPage {
  page: number;
  totalPages: number;
  items: BookListItem[];
}

export type ShelfItemType = 'BOOK' | 'FOLDER';

export interface ShelfBookItem {
  id: number;
  type: 'BOOK';
  index: number;
  parents: string[];
  updatedAt: string;
}

export interface ShelfFolderItem {
  id: string;
  type: 'FOLDER';
  index: number;
  parents: string[];
  updatedAt: string;
  title: string;
}

export type ShelfItem = ShelfBookItem | ShelfFolderItem;

export interface UserShelf {
  version: string | null;
  items: ShelfItem[];
}

export interface BookChapter {
  id: number;
  title: string;
}

export interface BookClassification {
  author: string | null;
  seriesName: string | null;
  seriesNameCn: string | null;
  tags: string[];
}

export interface BookDetailUser {
  id: number;
  userName: string;
  avatarUrl: string;
}

export interface BookReadPosition {
  chapterId: number;
  position: string;
}

export interface BookDetail {
  id: number;
  coverUrl: string;
  coverPlaceholder: string | null;
  title: string;
  authorName: string | null;
  category: BookCategory | null;
  introduction: string;
  lastUpdatedChapter: string | null;
  lastUpdatedAt: string;
  createdAt: string;
  favoriteCount: number;
  viewCount: number;
  canEdit: boolean;
  chapters: BookChapter[];
  user: BookDetailUser | null;
  classification: BookClassification;
  readPosition: BookReadPosition | null;
}

export type TextConversionMode = 't2s' | 's2t';

export interface NovelContentRequest {
  bookId: number;
  sortNum: number;
  convert?: TextConversionMode;
}

export interface NovelChapterContent {
  id: number;
  bookId: number;
  title: string;
  content: string;
  fontUrl: string | null;
  sortNum: number;
  chapterTitles: string[];
  canEdit: boolean;
}

export interface NovelContent {
  chapter: NovelChapterContent;
  readPosition: BookReadPosition | null;
}

export type CommentTargetType = 'Book' | 'Announcement' | 'Series';

export interface CommentUser {
  id: number;
  userName: string;
  avatarUrl: string;
}

export interface CommentReply {
  id: number;
  user: CommentUser;
  content: string;
  createdAt: string;
  canEdit: boolean;
  replyToUser: CommentUser | null;
}

export interface CommentItem {
  id: number;
  user: CommentUser;
  content: string;
  createdAt: string;
  canEdit: boolean;
  replies: CommentReply[];
}

export interface CommentPage {
  page: number;
  totalPages: number;
  items: CommentItem[];
}

export interface GetCommentsRequest {
  type: CommentTargetType;
  id: number;
  page: number;
  seriesTitle?: string;
}

export interface PostCommentRequest {
  type: CommentTargetType;
  id: number;
  content: string;
  seriesTitle?: string;
  parentId?: number;
  replyId?: number;
}

export interface OnlineInfo {
  onlineUserCount: number;
  maxOnline: number;
  dayCount: number;
  dayRegister: number;
}

export interface AnnouncementItem {
  id: number;
  title: string;
  createdAt: string;
}

export interface AnnouncementPage {
  page: number;
  totalPages: number;
  items: AnnouncementItem[];
}

export interface LatestBooksRequest {
  ignoreJapanese?: boolean;
  ignoreAI?: boolean;
  size?: number;
}

export interface AnnouncementListRequest {
  page: number;
  size: number;
}

export class ApiClient {
  readonly #transport: HttpTransport;
  readonly #signalR: SignalRTransport;
  readonly #authRetry: AuthRetryHandler | null;

  constructor(
    transport: HttpTransport,
    signalR: SignalRTransport,
    authRetry: AuthRetryHandler | null = null,
  ) {
    this.#transport = transport;
    this.#signalR = signalR;
    this.#authRetry = authRetry;
  }

  request<T>(request: ApiRequest): Promise<HttpResponse<T>> {
    return this.#requestWithAuthRetry(request);
  }

  async #requestWithAuthRetry<T>(
    request: ApiRequest,
    hasRetried = false,
  ): Promise<HttpResponse<T>> {
    const { path, query, ...transportRequest } = request;
    const response = await this.#transport.request<T>({
      ...transportRequest,
      url: buildApiUrl(path, query),
    });

    if (response.status !== 401 || hasRetried || this.#authRetry === null) {
      return response;
    }

    if (!(await this.#authRetry.refresh())) {
      throw new ApiError('Sign in is required.', 'auth', { status: 401 });
    }

    return this.#requestWithAuthRetry(request, true);
  }

  async invoke<T>(
    methodName: string,
    params: JsonValue | undefined,
    decode: (value: unknown) => T,
  ): Promise<T> {
    for (let hasRetried = false; ; hasRetried = true) {
      try {
        const envelope = await this.#signalR.invoke<unknown>(methodName, [
          params,
          { UseGzip: SIGNALR_OPTIONS.useGzip },
        ]);
        return decodeSignalRResponse(envelope, decode);
      } catch (error) {
        const apiError = toApiError(error);
        if (apiError.category !== 'auth' || hasRetried || this.#authRetry === null) {
          throw apiError;
        }
        if (!(await this.#authRetry.refresh())) {
          throw apiError;
        }
      }
    }
  }

  getLatestBookList(request: LatestBooksRequest = {}): Promise<BookListPage> {
    return this.invoke(
      'GetLatestBookList',
      {
        IgnoreJapanese: request.ignoreJapanese ?? false,
        IgnoreAI: request.ignoreAI ?? false,
        ...(request.size === undefined ? {} : { Size: request.size }),
      },
      decodeBookListPage,
    );
  }

  getOnlineInfo(): Promise<OnlineInfo> {
    return this.invoke('GetOnlineInfo', undefined, decodeOnlineInfo);
  }

  getAnnouncementList(
    request: AnnouncementListRequest = { page: 1, size: 5 },
  ): Promise<AnnouncementPage> {
    return this.invoke(
      'GetAnnouncementList',
      { Page: request.page, Size: request.size },
      decodeAnnouncementPage,
    );
  }

  getBookInfo(id: number): Promise<BookDetail> {
    return this.invoke('GetBookInfo', { Id: id }, decodeBookDetail);
  }

  getNovelContent(request: NovelContentRequest): Promise<NovelContent> {
    return this.invoke(
      'GetNovelContent',
      {
        Bid: request.bookId,
        SortNum: request.sortNum,
        ...(request.convert === undefined ? {} : { Convert: request.convert }),
      },
      decodeNovelContent,
    );
  }

  getComments(request: GetCommentsRequest): Promise<CommentPage> {
    return this.invoke(
      'GetComments',
      {
        Type: request.type,
        Id: request.id,
        Page: request.page,
        ...(request.seriesTitle === undefined
          ? {}
          : { SeriesTitle: request.seriesTitle }),
      },
      decodeCommentPage,
    );
  }

  postComment(request: PostCommentRequest): Promise<void> {
    return this.invoke('PostComment', encodeCommentRequest(request), () => undefined);
  }

  replyComment(request: PostCommentRequest): Promise<void> {
    return this.invoke('ReplyComment', encodeCommentRequest(request), () => undefined);
  }

  deleteComment(id: number): Promise<void> {
    return this.invoke('DeleteComment', { Id: id }, () => undefined);
  }

  getBookShelf(): Promise<UserShelf> {
    return this.invoke('GetBookShelf', undefined, decodeUserShelf);
  }

  saveBookShelf(shelf: UserShelf): Promise<void> {
    return this.invoke(
      'SaveBookShelf',
      {
        data: shelf.items.map(encodeShelfItem),
        ver: shelf.version ?? SHELF_STRUCT_VERSION,
      },
      () => undefined,
    );
  }

  getBookListByIds(ids: number[]): Promise<BookListItem[]> {
    const uniqueIds = [...new Set(ids)];
    if (uniqueIds.length > 24) {
      return Promise.reject(new Error('A single shelf request cannot contain more than 24 books.'));
    }
    if (uniqueIds.length === 0) return Promise.resolve([]);
    return this.invoke('GetBookListByIds', { Ids: uniqueIds }, decodeBookListItems);
  }

  async login(request: LoginRequest): Promise<SessionTokens> {
    const response = await this.#transport.request<unknown>({
      body: {
        email: request.email,
        password: request.passwordHash,
      },
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      method: 'POST',
      url: `${SERVICE_ENDPOINTS.apiOrigin}${SERVICE_ENDPOINTS.loginPath}`,
    });
    if (response.status < 200 || response.status >= 300) {
      throw new ApiError('Unable to sign in.', response.status === 401 ? 'auth' : 'server', {
        status: response.status,
      });
    }
    return decodeSessionTokens(response.body);
  }

  async register(request: RegisterRequest): Promise<SessionTokens> {
    const response = await this.#transport.request<unknown>({
      body: {
        userName: request.userName,
        email: request.email,
        password: request.passwordHash,
        code: request.code,
        inviteCode: request.inviteCode,
      },
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      method: 'POST',
      url: `${SERVICE_ENDPOINTS.apiOrigin}${SERVICE_ENDPOINTS.registerPath}`,
    });
    if (response.status < 200 || response.status >= 300) {
      throw new ApiError('Unable to create your account.', response.status === 401 ? 'auth' : 'server', {
        status: response.status,
      });
    }
    return decodeSessionTokens(response.body);
  }

  async sendRegisterEmail(email: string): Promise<void> {
    await this.#requestEmailCode(SERVICE_ENDPOINTS.sendRegisterEmailPath, email);
  }

  async sendResetEmail(email: string): Promise<void> {
    await this.#requestEmailCode(SERVICE_ENDPOINTS.sendResetEmailPath, email);
  }

  async resetPassword(request: ResetPasswordRequest): Promise<void> {
    const response = await this.#transport.request<unknown>({
      body: {
        email: request.email,
        newPassword: request.newPasswordHash,
        code: request.code,
      },
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      method: 'POST',
      url: `${SERVICE_ENDPOINTS.apiOrigin}${SERVICE_ENDPOINTS.resetPasswordPath}`,
    });
    if (response.status < 200 || response.status >= 300) {
      throw new ApiError('Unable to reset your password.', response.status === 401 ? 'auth' : 'server', {
        status: response.status,
      });
    }
    decodeSuccessfulResponse(response.body, 'Unable to reset your password.');
  }

  async #requestEmailCode(path: string, email: string): Promise<void> {
    const response = await this.#transport.request<unknown>({
      method: 'GET',
      url: buildApiUrl(path, { email }),
    });
    if (response.status < 200 || response.status >= 300) {
      throw new ApiError('Unable to send the verification code.', 'server', {
        status: response.status,
      });
    }
    decodeSuccessfulResponse(response.body, 'Unable to send the verification code.');
  }

  async refreshToken(refreshToken: string): Promise<string> {
    if (!refreshToken) {
      throw new ApiError('Sign in is required.', 'auth', { status: 401 });
    }

    const response = await this.#transport.request<unknown>({
      body: { token: refreshToken },
      headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
      method: 'POST',
      url: `${SERVICE_ENDPOINTS.apiOrigin}${SERVICE_ENDPOINTS.refreshTokenPath}`,
    });
    if (response.status < 200 || response.status >= 300) {
      throw new ApiError(
        'Your session has expired. Sign in again to continue.',
        response.status === 401 || response.status === 404 ? 'auth' : 'server',
        { status: response.status },
      );
    }
    return decodeRefreshToken(response.body);
  }
}

export function decodeSignalRResponse<T>(
  value: unknown,
  decode: (response: unknown) => T,
): T {
  if (!isRecord(value) || typeof value.Success !== 'boolean') {
    throw new ApiError('The server returned an invalid response.', 'server');
  }

  if (!value.Success) {
    const status = typeof value.Status === 'number' ? value.Status : undefined;
    const message = typeof value.Msg === 'string' ? value.Msg : 'Request failed.';
    throw new ApiError(
      message,
      status === 401 || status === -100 ? 'auth' : 'server',
      status === undefined ? {} : { status },
    );
  }

  return decode(decodeCompressedResponse(value.Response));
}

function decodeCompressedResponse(value: unknown): unknown {
  if (!(value instanceof Uint8Array)) return value;
  try {
    return JSON.parse(ungzip(value, { to: 'string' }));
  } catch (error) {
    throw new ApiError('The server returned an invalid compressed response.', 'server', {
      cause: error,
    });
  }
}

export function decodeBookListPage(value: unknown): BookListPage {
  const record = asRecord(value, 'book list response');
  const rawItems = asArray(record.Data, 'book list items');

  return {
    page: asNumber(record.Page, 1),
    totalPages: asNumber(record.TotalPages, 1),
    items: rawItems.map(decodeBookListItem),
  };
}

export function decodeBookListItems(value: unknown): BookListItem[] {
  const rawItems = Array.isArray(value)
    ? value
    : isRecord(value) && Array.isArray(value.Data)
      ? value.Data
      : null;
  if (rawItems === null) {
    throw new ApiError('Invalid book list items.', 'server');
  }
  return rawItems.map(decodeBookListItem);
}

export function decodeUserShelf(value: unknown): UserShelf {
  const record = isRecord(value) ? value : null;
  const rawItems = Array.isArray(value)
    ? value
    : record && Array.isArray(record.data)
      ? record.data
      : record && Array.isArray(record.Data)
        ? record.Data
        : null;
  if (rawItems === null) {
    throw new ApiError('Invalid shelf response.', 'server');
  }

  const versionValue = record?.ver ?? record?.Ver;
  return {
    version:
      typeof versionValue === 'string' || typeof versionValue === 'number'
        ? String(versionValue)
        : null,
    items: rawItems.map(decodeShelfItem),
  };
}

export function decodeOnlineInfo(value: unknown): OnlineInfo {
  const record = asRecord(value, 'online info');
  return {
    onlineUserCount: asNumber(record.OnlineUserCount),
    maxOnline: asNumber(record.MaxOnline),
    dayCount: asNumber(record.DayCount),
    dayRegister: asNumber(record.DayRegister),
  };
}

export function decodeAnnouncementPage(value: unknown): AnnouncementPage {
  const record = asRecord(value, 'announcement response');
  const rawItems = asArray(record.Data, 'announcement items');
  return {
    page: asNumber(record.Page, 1),
    totalPages: asNumber(record.TotalPages, 1),
    items: rawItems.map((item) => {
      const announcement = asRecord(item, 'announcement item');
      return {
        id: asNumber(announcement.Id),
        title: asString(announcement.Title),
        createdAt: asDateString(announcement.CreatedAt),
      };
    }),
  };
}

export function decodeBookDetail(value: unknown): BookDetail {
  const response = asRecord(value, 'book detail response');
  const book = asRecord(response.Book ?? response, 'book detail');
  const classification = decodeBookClassification(book.Extra);
  const category = decodeOptionalBookCategory(book.Category);

  return {
    id: asNumber(book.Id),
    coverUrl: asString(book.Cover),
    coverPlaceholder: extractCoverPlaceholder(asString(book.Cover)),
    title: asString(book.Title),
    authorName: asNullableString(book.Author) ?? classification.author,
    category,
    introduction: asStringOrEmpty(book.Introduction),
    lastUpdatedChapter: asNullableString(book.LastUpdatedChapter),
    lastUpdatedAt: asDateString(book.LastUpdatedAt),
    createdAt: asDateString(book.CreatedAt),
    favoriteCount: asNumber(book.Favorite, 0),
    viewCount: asNumber(book.Views, 0),
    canEdit: book.CanEdit === true,
    chapters: decodeBookChapters(book.Chapter),
    user: decodeBookDetailUser(book.User),
    classification,
    readPosition: decodeBookReadPosition(response.ReadPosition),
  };
}

export function decodeNovelContent(value: unknown): NovelContent {
  const response = asRecord(value, 'novel content response');
  const chapter = asRecord(response.Chapter, 'novel chapter');

  return {
    chapter: {
      id: asNumber(chapter.Id),
      bookId: asNumber(chapter.BookId, 0),
      title: asString(chapter.Title),
      content: asStringOrEmpty(chapter.Content),
      fontUrl: asNullableString(chapter.Font),
      sortNum: asNumber(chapter.SortNum),
      chapterTitles: decodeStringArray(chapter.Chapters),
      canEdit: chapter.CanEdit === true,
    },
    readPosition: decodeBookReadPosition(response.ReadPosition),
  };
}

export function decodeCommentPage(value: unknown): CommentPage {
  const response = asRecord(value, 'comments response');
  const users = asRecord(response.Users, 'comment users');
  const commentaries = asRecord(response.Commentaries, 'commentaries');
  const roots = asArray(response.Data, 'comment roots');

  function getUser(userId: number): CommentUser {
    const user = asRecord(users[String(userId)], 'comment user');
    return {
      id: asNumber(user.Id, userId),
      userName: asString(user.UserName),
      avatarUrl: asStringOrEmpty(user.Avatar),
    };
  }

  function getCommentary(commentId: number): Record<string, unknown> {
    return asRecord(commentaries[String(commentId)], 'commentary');
  }

  return {
    page: asNumber(response.Page, 1),
    totalPages: asNumber(response.TotalPages, 0),
    items: roots.map((rootValue) => {
      const root = asRecord(rootValue, 'comment root');
      const id = asNumber(root.Id);
      const commentary = getCommentary(id);
      const replies = Array.isArray(root.Reply) ? root.Reply.map((value) => asNumber(value)) : [];
      return {
        id,
        user: getUser(asNumber(commentary.UserId)),
        content: asStringOrEmpty(commentary.Content),
        createdAt: asDateString(commentary.CreatedAt),
        canEdit: commentary.CanEdit === true,
        replies: replies.map((replyId) => {
          const reply = getCommentary(replyId);
          const replyToId = asNullableNumber(reply.ReplyId);
          const replyTo = replyToId === null ? null : getCommentary(replyToId);
          return {
            id: replyId,
            user: getUser(asNumber(reply.UserId)),
            content: asStringOrEmpty(reply.Content),
            createdAt: asDateString(reply.CreatedAt),
            canEdit: reply.CanEdit === true,
            replyToUser:
              replyTo === null ? null : getUser(asNumber(replyTo.UserId)),
          };
        }),
      };
    }),
  };
}

function encodeCommentRequest(request: PostCommentRequest): JsonValue {
  return {
    Type: request.type,
    Id: request.id,
    Content: request.content,
    ...(request.seriesTitle === undefined
      ? {}
      : { SeriesTitle: request.seriesTitle }),
    ...(request.parentId === undefined ? {} : { ParentId: request.parentId }),
    ...(request.replyId === undefined ? {} : { ReplyId: request.replyId }),
  };
}

export function decodeSessionTokens(value: unknown): SessionTokens {
  const envelope = asRecord(value, 'login response');
  if (envelope.Success === false) {
    const status = typeof envelope.Status === 'number' ? envelope.Status : undefined;
    throw new ApiError(
      typeof envelope.Msg === 'string' ? envelope.Msg : 'Unable to sign in.',
      status === 401 || status === -100 ? 'auth' : 'server',
      status === undefined ? {} : { status },
    );
  }
  const response = isRecord(envelope.Response) ? envelope.Response : envelope;
  return {
    sessionToken: asString(response.Token),
    refreshToken: asString(response.RefreshToken),
  };
}

export function decodeRefreshToken(value: unknown): string {
  const envelope = asRecord(value, 'refresh token response');
  if (envelope.Success === false) {
    const status = typeof envelope.Status === 'number' ? envelope.Status : undefined;
    throw new ApiError(
      typeof envelope.Msg === 'string'
        ? envelope.Msg
        : 'Your session has expired. Sign in again to continue.',
      status === 401 || status === -100 || status === 404 ? 'auth' : 'server',
      status === undefined ? {} : { status },
    );
  }
  const token = envelope.Response ?? envelope.Token;
  return asString(token);
}

function decodeBookListItem(value: unknown): BookListItem {
  const book = asRecord(value, 'book list item');
  // MessagePack serializes the backend enum as its numeric value. The Web
  // reference types expose the string form, so accept both wire variants.
  const type = book.Type === 'Comic' || book.Type === 1 ? 'Comic' : 'Novel';
  return {
    id: asNumber(book.Id),
    type,
    title: asString(book.Title),
    seriesTitle: asNullableString(book.SeriesTitle),
    coverUrl: asString(book.Cover),
    coverPlaceholder: extractCoverPlaceholder(asString(book.Cover)),
    authorName: asNullableString(book.UserName),
    lastUpdatedAt: asDateString(book.LastUpdatedAt),
    level: asNullableNumber(book.Level),
    interiorLevel: asNullableNumber(book.InteriorLevel),
    category: decodeBookCategory(book.Category),
  };
}

function decodeShelfItem(value: unknown): ShelfItem {
  const item = asRecord(value, 'shelf item');
  const rawType = item.type ?? item.Type;
  const type = normalizeShelfItemType(rawType);
  const index = asNumber(item.index ?? item.Index, 0);
  const parents = decodeStringArray(item.parents ?? item.Parents);
  const updatedAt = asStringOrEmpty(item.updateAt ?? item.UpdateAt);

  if (type === 'BOOK') {
    return {
      id: asNumber(item.id ?? item.Id),
      index,
      parents,
      type,
      updatedAt,
    };
  }

  return {
    id: asShelfIdString(item.id ?? item.Id),
    index,
    parents,
    title: asStringOrEmpty(item.title ?? item.Title),
    type,
    updatedAt,
  };
}

function encodeShelfItem(item: ShelfItem): JsonValue {
  return item.type === 'BOOK'
    ? {
        id: item.id,
        index: item.index,
        parents: item.parents,
        type: item.type,
        updateAt: item.updatedAt,
      }
    : {
        id: item.id,
        index: item.index,
        parents: item.parents,
        title: item.title,
        type: item.type,
        updateAt: item.updatedAt,
      };
}

function normalizeShelfItemType(value: unknown): ShelfItemType {
  if (value === 'BOOK' || value === 'Book' || value === 0) return 'BOOK';
  if (value === 'FOLDER' || value === 'Folder' || value === 1) return 'FOLDER';
  throw new ApiError('The server returned an invalid shelf item type.', 'server');
}

function asShelfIdString(value: unknown): string {
  if (typeof value === 'string' && value.length > 0) return value;
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  throw new ApiError('The server returned an invalid shelf item id.', 'server');
}

function decodeBookCategory(value: unknown): BookCategory | null {
  if (value === null || value === undefined) return null;
  const category = asRecord(value, 'book category');
  return {
    name: asString(category.Name),
    shortName: asString(category.ShortName),
    color: asString(category.Color),
  };
}

function decodeOptionalBookCategory(value: unknown): BookCategory | null {
  return value === null || value === undefined ? null : decodeBookCategory(value);
}

function decodeBookClassification(value: unknown): BookClassification {
  if (!isRecord(value) || !isRecord(value.classification)) {
    return { author: null, seriesName: null, seriesNameCn: null, tags: [] };
  }

  const classification = value.classification;
  return {
    author: asNullableString(classification.author),
    seriesName: asNullableString(classification.series_name),
    seriesNameCn: asNullableString(classification.series_name_cn),
    tags: decodeStringArray(classification.tags),
  };
}

function decodeBookChapters(value: unknown): BookChapter[] {
  if (!Array.isArray(value)) return [];
  return value.map((item) => {
    const chapter = asRecord(item, 'book chapter');
    return { id: asNumber(chapter.Id), title: asString(chapter.Title) };
  });
}

function decodeBookDetailUser(value: unknown): BookDetailUser | null {
  if (!isRecord(value)) return null;
  return {
    id: asNumber(value.Id),
    userName: asString(value.UserName),
    avatarUrl: asStringOrEmpty(value.Avatar),
  };
}

function decodeBookReadPosition(value: unknown): BookReadPosition | null {
  if (!isRecord(value)) return null;
  const chapterId = asNumber(value.ChapterId, 0);
  if (chapterId <= 0) return null;
  return {
    chapterId,
    position: asStringOrEmpty(value.Position),
  };
}

function decodeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === 'string' && item.length > 0);
}

function asRecord(value: unknown, name: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new ApiError(`Invalid ${name}.`, 'server');
  }
  return value as Record<string, unknown>;
}

function asArray(value: unknown, name: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new ApiError(`Invalid ${name}.`, 'server');
  }
  return value;
}

function asString(value: unknown): string {
  if (typeof value !== 'string' || value.length === 0) {
    throw new ApiError('The server returned an invalid text field.', 'server');
  }
  return value;
}

function asStringOrEmpty(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function asNullableString(value: unknown): string | null {
  return value === null || value === undefined ? null : asString(value);
}

function asNumber(value: unknown, fallback?: number): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (fallback !== undefined) return fallback;
  throw new ApiError('The server returned an invalid number field.', 'server');
}

function asNullableNumber(value: unknown): number | null {
  return value === null || value === undefined ? null : asNumber(value);
}

function asDateString(value: unknown): string {
  if (value instanceof Date) return value.toISOString();
  return asString(value);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isAuthenticationError(message: string): boolean {
  return /401|unauthori[sz]ed|invalid token|无效token|未登录|授权/i.test(message);
}

function toApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error;
  const message = error instanceof Error ? error.message : '';
  const category = isAuthenticationError(message) ? 'auth' : 'network';
  return new ApiError(
    category === 'auth' ? 'Sign in is required.' : 'Unable to connect to LightNovelShelf.',
    category,
    { cause: error },
  );
}

function extractCoverPlaceholder(value: string): string | null {
  try {
    const placeholder = new URL(value).searchParams.get('placeholder');
    return placeholder && placeholder.length >= 6 ? placeholder : null;
  } catch {
    return null;
  }
}

function buildApiUrl(
  path: string,
  query?: Readonly<Record<string, string>>,
): string {
  const url = new URL(`${SERVICE_ENDPOINTS.apiOrigin}${path}`);
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      url.searchParams.set(key, value);
    }
  }
  return url.toString();
}

function decodeSuccessfulResponse(value: unknown, fallbackMessage: string): unknown {
  if (value === undefined || value === null) return undefined;
  const envelope = asRecord(value, 'HTTP response');
  if (envelope.Success === false) {
    const status = typeof envelope.Status === 'number' ? envelope.Status : undefined;
    throw new ApiError(
      typeof envelope.Msg === 'string' ? envelope.Msg : fallbackMessage,
      status === 401 || status === -100 ? 'auth' : 'server',
      status === undefined ? {} : { status },
    );
  }
  return envelope.Response;
}

export class ApiError extends Error {
  readonly category: 'auth' | 'network' | 'server' | 'unknown';
  readonly status?: number;

  constructor(
    message: string,
    category: ApiError['category'],
    options: { cause?: unknown; status?: number } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = 'ApiError';
    this.category = category;
    if (options.status !== undefined) {
      this.status = options.status;
    }
  }
}
