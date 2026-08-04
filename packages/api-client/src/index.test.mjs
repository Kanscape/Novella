import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ApiClient,
  RateLimitRequestScheduler,
  REQUEST_RATE_LIMIT,
  RequestCancelledError,
  decodeBookDetail,
  decodeComicContent,
  decodeComicInfo,
  decodeUserProfile,
  extractBlurHashPlaceholder,
  normalizeBlurHash,
} from './index.ts';

test('decodes book details whose optional Web-Master text fields are empty', () => {
  const detail = decodeBookDetail({
    Book: {
      Id: 11,
      Type: 'Novel',
      Cover: 'https://cdn.example/cover.png',
      Title: 'Series 1',
      Author: '',
      Category: null,
      Introduction: '',
      LastUpdatedChapter: '',
      LastUpdatedAt: '2026-01-02T00:00:00.000Z',
      CreatedAt: '2026-01-01T00:00:00.000Z',
      Favorite: 0,
      Views: 0,
      CanEdit: false,
      Chapter: [{ Id: 100, Title: 'Chapter 1' }],
      User: { Id: 4, UserName: 'uploader', Avatar: '' },
      Extra: {
        classification: {
          author: 'Classified author',
          series_name: '',
          series_name_cn: null,
          tags: [],
        },
      },
    },
    ReadPosition: null,
  });

  assert.equal(detail.authorName, null);
  assert.equal(detail.classification.author, 'Classified author');
  assert.equal(detail.lastUpdatedChapter, null);
  assert.equal(detail.classification.seriesName, null);
  assert.equal(detail.classification.seriesNameCn, null);
});

test('decodes the Web-Master profile and growth summary', () => {
  const profile = decodeUserProfile({
    Id: 42,
    UserName: 'reader',
    Avatar: 'https://cdn.example/avatar.png',
    Email: 'reader@example.com',
    InviteCode: 'INVITE',
    Role: { Name: 'Member' },
    Point: 320,
    UnreadNotificationCount: 3,
    RegisterAt: '2026-01-02T00:00:00.000Z',
    Growth: {
      Exp: 180,
      Level: 4,
      GrowthLevel: 3,
      CurrentLevelExp: 150,
      NextLevelExp: 240,
      SignStreak: 7,
      TodaySigned: true,
    },
  });

  assert.deepEqual(profile, {
    id: 42,
    userName: 'reader',
    avatarUrl: 'https://cdn.example/avatar.png',
    email: 'reader@example.com',
    inviteCode: 'INVITE',
    groupName: 'Member',
    point: 320,
    unreadNotificationCount: 3,
    registeredAt: '2026-01-02T00:00:00.000Z',
    growth: {
      experience: 180,
      level: 4,
      growthLevel: 3,
      currentLevelExperience: 150,
      nextLevelExperience: 240,
      signInStreak: 7,
      signedToday: true,
    },
  });

  const legacyProfile = decodeUserProfile({ Id: 43, RegisterAt: '' });
  assert.equal(legacyProfile.registeredAt, null);
  assert.equal(legacyProfile.growth.experience, 0);
  assert.equal(legacyProfile.growth.signedToday, false);
});

test('maps profile, avatar, and check-in to Web-Master Hub contracts', async () => {
  const calls = [];
  const client = new ApiClient(
    { async request() { throw new Error('not used'); } },
    {
      async connect() {},
      async close() {},
      async invoke(method, args) {
        calls.push({ method, args });
        if (method === 'GetMyInfo') {
          return { Success: true, Response: { Id: 8, UserName: 'reader' } };
        }
        if (method === 'SignIn') {
          return { Success: true, Response: { Reward: 5, Streak: 2, Exp: 20, Level: 1 } };
        }
        return { Success: true, Response: null };
      },
    },
    null,
    new RateLimitRequestScheduler(20, 10),
  );

  assert.equal((await client.getMyProfile()).id, 8);
  await client.setAvatar('https://cdn.example/avatar.png');
  assert.deepEqual(await client.checkIn(), {
    reward: 5,
    streak: 2,
    experience: 20,
    level: 1,
  });
  assert.deepEqual(calls, [
    { method: 'GetMyInfo', args: [{}, { UseGzip: true }] },
    { method: 'SetAvatar', args: [{ Url: 'https://cdn.example/avatar.png' }, { UseGzip: true }] },
    { method: 'SignIn', args: [{}, { UseGzip: true }] },
  ]);
});

test('decodes Web-Master comic info and preserves the reader position', () => {
  const info = decodeComicInfo({
    Book: {
      Id: 12,
      Cover: 'https://cdn.example/cover.png?placeholder=LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      Title: 'Series 1',
      Author: '',
      Extra: { classification: { author: 'Classified author' } },
      Views: 42,
      Introduction: 'summary',
      CreatedAt: '2026-01-01T00:00:00.000Z',
      LastUpdatedChapter: 'Chapter 3',
      LastUpdatedAt: '2026-01-02T00:00:00.000Z',
      Favorite: 7,
      User: { Id: 4, UserName: 'uploader', Avatar: '' },
      Chapters: [{ Id: 100, SortNum: 1, Title: 'Chapter 1', CreatedAt: '2026-01-01T00:00:00.000Z', PageCount: 3 }],
    },
    ReadPosition: { ChapterId: 100, Position: '2' },
  });

  assert.equal(info.id, 12);
  assert.equal(info.coverPlaceholder, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
  assert.equal(info.authorName, null);
  assert.equal(info.classification.author, 'Classified author');
  assert.equal(info.chapters[0].pageCount, 3);
  assert.deepEqual(info.readPosition, { chapterId: 100, position: '2' });
});

test('maps novel and comic search to their Web-Master Hub contracts', async () => {
  const calls = [];
  const client = new ApiClient(
    { async request() { throw new Error('not used'); } },
    {
      async connect() {},
      async close() {},
      async invoke(method, args) {
        calls.push({ method, args });
        if (method === 'GetBookList') {
          return {
            Success: true,
            Response: {
              Page: 2,
              TotalPages: 4,
              Data: [{
                Id: 7,
                Type: 'Novel',
                Title: 'Novel result',
                Cover: 'https://cdn.example/novel.jpg',
                UserName: '',
                LastUpdatedAt: '2026-01-01T00:00:00.000Z',
                Category: null,
              }],
            },
          };
        }
        return {
          Success: true,
          Response: {
            Page: 1,
            TotalPages: 3,
            Data: [{
              Id: 9,
              Title: 'Comic series',
              OriginalTitle: '',
              Cover: 'https://cdn.example/comic.jpg',
              Count: 2,
              LastUpdatedAt: '2026-01-02T00:00:00.000Z',
            }],
          },
        };
      },
    },
    null,
    new RateLimitRequestScheduler(20, 10),
  );

  const novels = await client.searchNovelBooks({
    keywords: 'query',
    mode: 'exact',
    page: 2,
    size: 24,
    ignoreJapanese: true,
  });
  const comics = await client.searchComicSeries({
    keywords: 'tag one,tag two',
    mode: 'tags',
    page: 1,
    size: 24,
    ignoreAI: true,
  });

  assert.equal(novels.items[0].title, 'Novel result');
  assert.equal(comics.items[0].title, 'Comic series');
  assert.equal(comics.items[0].originalTitle, null);
  assert.deepEqual(calls, [
    {
      method: 'GetBookList',
      args: [{
        KeyWords: '"query"',
        Page: 2,
        Size: 24,
        IgnoreJapanese: true,
        IgnoreAI: false,
      }, { UseGzip: true }],
    },
    {
      method: 'SearchComicSeries',
      args: [{
        KeyWords: 'tag one,tag two',
        Page: 1,
        Size: 24,
        IgnoreJapanese: false,
        IgnoreAI: true,
        Mode: 'tags',
      }, { UseGzip: true }],
    },
  ]);
});

test('decodes dual-format history and comic history hydration', async () => {
  const calls = [];
  const client = new ApiClient(
    { async request() { throw new Error('not used'); } },
    {
      async connect() {},
      async close() {},
      async invoke(method, args) {
        calls.push({ method, args });
        if (method === 'GetReadHistory') {
          return { Success: true, Response: { Novel: [3, 2], Comic: [11, 10] } };
        }
        if (method === 'GetBookListByIds') {
          return {
            Success: true,
            Response: {
              Page: 1,
              TotalPages: 1,
              Data: [{
                Id: 21,
                Title: 'Comic series',
                Cover: 'comic.jpg',
                Count: 3,
                LastUpdatedAt: '2026-01-02T00:00:00.000Z',
              }],
            },
          };
        }
        return { Success: true, Response: null };
      },
    },
    null,
    new RateLimitRequestScheduler(20, 10),
  );

  assert.deepEqual(await client.getReadHistory(), {
    novelIds: [3, 2],
    comicIds: [11, 10],
  });
  const comics = await client.getComicSeriesByIds([11, 11, 10]);
  assert.equal(comics.items[0].chapterCount, 3);
  await client.clearReadHistory();

  assert.deepEqual(calls.map(({ method }) => method), [
    'GetReadHistory',
    'GetBookListByIds',
    'ClearReadHistory',
  ]);
  assert.deepEqual(calls[1].args, [
    { Ids: [11, 10], Type: 'Comic' },
    { UseGzip: true },
  ]);
});

test('round-trips the versioned shelf document payload', async () => {
  const calls = [];
  const client = new ApiClient(
    { async request() { throw new Error('not used'); } },
    {
      async connect() {},
      async close() {},
      async invoke(method, args) {
        calls.push({ method, args });
        if (method === 'GetBookShelf') {
          return {
            Success: true,
            Response: {
              ver: '20220211',
              data: [
                { type: 'FOLDER', id: 'f1', title: 'Folder', index: 0, parents: [], updateAt: 'a' },
                { type: 'BOOK', id: 3, index: 0, parents: ['f1'], updateAt: 'b' },
              ],
            },
          };
        }
        return { Success: true, Response: null };
      },
    },
    null,
    new RateLimitRequestScheduler(20, 10),
  );

  const shelf = await client.getBookShelf();
  assert.equal(shelf.items[0].type, 'FOLDER');
  assert.deepEqual(shelf.items[1].parents, ['f1']);
  await client.saveBookShelf(shelf);
  assert.deepEqual(calls[1], {
    method: 'SaveBookShelf',
    args: [{
      data: [
        { type: 'FOLDER', id: 'f1', title: 'Folder', index: 0, parents: [], updateAt: 'a' },
        { type: 'BOOK', id: 3, index: 0, parents: ['f1'], updateAt: 'b' },
      ],
      ver: '20220211',
    }, { UseGzip: true }],
  });
});

test('decodes comic image batches using server skip and dimensions', () => {
  const content = decodeComicContent({
    Chapter: {
      Id: 100,
      BookId: 12,
      BookName: 'Series 1',
      Title: 'Chapter 1',
      SortNum: 1,
      Total: 24,
      Skip: 12,
      Images: [{ Url: 'https://cdn.example/13.jpg', Placeholder: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj', Width: 800, Height: 1200 }],
    },
  });

  assert.equal(content.chapter.total, 24);
  assert.equal(content.chapter.skip, 12);
  assert.deepEqual(content.chapter.images[0], {
    url: 'https://cdn.example/13.jpg',
    placeholder: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
    width: 800,
    height: 1200,
  });
});

test('validates BlurHash characters, components, and cover URL extraction', () => {
  const valid = 'LEHV6nWB2yk8pyo0adR*.7kCMdnj';
  assert.equal(normalizeBlurHash(valid), valid);
  assert.equal(normalizeBlurHash('LEHV6nWB2yk8pyo0adR*.7kCMdn!'), null);
  assert.equal(normalizeBlurHash(valid.slice(0, -1)), null);
  assert.equal(
    extractBlurHashPlaceholder(`https://cdn.example/cover.jpg?placeholder=${encodeURIComponent(valid)}`),
    valid,
  );
  assert.equal(
    extractBlurHashPlaceholder(`/cover.jpg?placeholder=${encodeURIComponent(valid)}`),
    valid,
  );
  // Raw URLs with unencoded base83 chars (legacy data): `+` must stay a literal
  // `+`, never become a space; invalid `%XX` sequences stay untouched.
  const rawWithPlus = 'JHM@}@EL~p%1gKn+';
  assert.equal(
    extractBlurHashPlaceholder(`https://img.example/md.jpg?placeholder=${rawWithPlus}&t=abc`),
    rawWithPlus,
  );
  assert.equal(
    extractBlurHashPlaceholder(`https://img.example/md.jpg?placeholder=JCL|i+@;_3^J^i-W`),
    'JCL|i+@;_3^J^i-W',
  );
  assert.equal(extractBlurHashPlaceholder('https://cdn.example/cover.jpg'), null);
});

test('drops invalid comic BlurHash placeholders at the API boundary', () => {
  const content = decodeComicContent({
    Chapter: {
      Id: 100,
      BookId: 12,
      Title: 'Chapter 1',
      SortNum: 1,
      Total: 1,
      Skip: 0,
      Images: [{ Url: 'page.jpg', Placeholder: 'invalid', Width: 2, Height: 3 }],
    },
  });
  assert.equal(content.chapter.images[0].placeholder, '');
});

test('uses the Web-Master request window for shared scheduling', async () => {
  let now = 0;
  const sleeps = [];
  const starts = [];
  const scheduler = new RateLimitRequestScheduler(
    1,
    10,
    () => now,
    async (milliseconds) => {
      sleeps.push(milliseconds);
      now += milliseconds;
    },
  );

  await Promise.all([
    scheduler.add(async () => starts.push('first')),
    scheduler.add(async () => starts.push('second')),
  ]);

  assert.deepEqual(REQUEST_RATE_LIMIT, {
    maxRequests: 9,
    windowMilliseconds: 5_500,
  });
  assert.deepEqual(starts, ['first', 'second']);
  assert.deepEqual(sleeps, [10]);
});

test('starts queued interactive Hub work before preload work', async () => {
  let now = 0;
  const starts = [];
  const sleepers = [];
  const scheduler = new RateLimitRequestScheduler(
    1,
    10,
    () => now,
    (milliseconds) => new Promise((resolve) => {
      sleepers.push(() => {
        now += milliseconds;
        resolve();
      });
    }),
  );

  await scheduler.add(async () => starts.push('first'));
  const preload = scheduler.add(
    async () => starts.push('preload'),
    { priority: 'preload' },
  );
  const interactive = scheduler.add(async () => starts.push('interactive'));

  assert.equal(sleepers.length, 1);
  sleepers.shift()();
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(sleepers.length, 1);
  sleepers.shift()();
  await Promise.all([preload, interactive]);

  assert.deepEqual(starts, ['first', 'interactive', 'preload']);
});

test('removes aborted preload work before it reaches the Hub', async () => {
  let now = 0;
  const starts = [];
  const sleepers = [];
  const scheduler = new RateLimitRequestScheduler(
    1,
    10,
    () => now,
    (milliseconds) => new Promise((resolve) => {
      sleepers.push(() => {
        now += milliseconds;
        resolve();
      });
    }),
  );

  await scheduler.add(async () => starts.push('first'));
  const controller = new AbortController();
  const preload = scheduler.add(
    async () => starts.push('preload'),
    { priority: 'preload', signal: controller.signal },
  );
  controller.abort();

  await assert.rejects(preload, RequestCancelledError);
  sleepers.shift()?.();
  await Promise.resolve();
  assert.deepEqual(starts, ['first']);
});

test('retries one SignalR NoToken failure and schedules each physical attempt', async () => {
  let invokeCalls = 0;
  let refreshCalls = 0;
  let now = 0;
  const sleeps = [];
  const scheduler = new RateLimitRequestScheduler(
    1,
    10,
    () => now,
    async (milliseconds) => {
      sleeps.push(milliseconds);
      now += milliseconds;
    },
  );
  const client = new ApiClient(
    { async request() { throw new Error('not used'); } },
    {
      async connect() {},
      async close() {},
      async invoke() {
        invokeCalls += 1;
        if (invokeCalls === 1) throw new Error('NoToken');
        return { Success: true, Response: { value: 7 } };
      },
    },
    {
      async refresh() {
        refreshCalls += 1;
        return true;
      },
    },
    scheduler,
  );

  const result = await client.invoke('TestOperation', undefined, (value) => value);
  assert.deepEqual(result, { value: 7 });
  assert.equal(refreshCalls, 1);
  assert.equal(invokeCalls, 2);
  assert.deepEqual(sleeps, [10]);
});
