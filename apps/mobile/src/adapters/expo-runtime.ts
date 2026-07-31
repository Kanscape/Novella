import * as SecureStore from 'expo-secure-store';
import * as SQLite from 'expo-sqlite';
import * as Crypto from 'expo-crypto';
import { AppState, type AppStateStatus } from 'react-native';
import {
  HubConnectionBuilder,
  HttpTransportType,
  LogLevel,
} from '@microsoft/signalr';
import { MessagePackHubProtocol } from '@microsoft/signalr-protocol-msgpack';

import type {
  AppLifecycle,
  Clock,
  CredentialStore,
  HttpRequest,
  HttpResponse,
  HttpTransport,
  JsonPrimitive,
  KeyValueStore,
  Logger,
  SignalRTransport,
  PasswordHasher,
  Unsubscribe,
} from '@novella/platform-contracts';

import { SERVICE_ENDPOINTS } from '@novella/api-client';
import { AUTH_CREDENTIAL_KEYS } from '@novella/client-core';

const VISITOR_ID_KEY = 'novella.visitor-id';

export class ExpoCredentialStore implements CredentialStore {
  get(key: string): Promise<string | null> {
    return SecureStore.getItemAsync(key);
  }

  set(key: string, value: string): Promise<void> {
    return SecureStore.setItemAsync(key, value);
  }

  delete(key: string): Promise<void> {
    return SecureStore.deleteItemAsync(key);
  }
}

class ExpoKeyValueStore implements KeyValueStore {
  readonly #database = SQLite.openDatabaseAsync('novella.db');
  readonly #initialized: Promise<void>;

  constructor() {
    this.#initialized = this.#database.then((database) =>
      database.execAsync(
        'CREATE TABLE IF NOT EXISTS key_value (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)',
      ),
    );
  }

  async get(key: string): Promise<string | null> {
    await this.#initialized;
    const database = await this.#database;
    const row = await database.getFirstAsync<{ value: string }>(
      'SELECT value FROM key_value WHERE key = ?',
      key,
    );
    return row?.value ?? null;
  }

  async set(key: string, value: string): Promise<void> {
    await this.#initialized;
    const database = await this.#database;
    await database.runAsync(
      'INSERT OR REPLACE INTO key_value (key, value) VALUES (?, ?)',
      key,
      value,
    );
  }

  async delete(key: string): Promise<void> {
    await this.#initialized;
    const database = await this.#database;
    await database.runAsync('DELETE FROM key_value WHERE key = ?', key);
  }
}

export class ExpoHttpTransport implements HttpTransport {
  readonly #credentials: CredentialStore;

  constructor(credentials: CredentialStore) {
    this.#credentials = credentials;
  }

  async request<T>(request: HttpRequest): Promise<HttpResponse<T>> {
    const headers = new Headers(request.headers);
    headers.set('Accept', 'application/json');
    headers.set('Content-Type', 'application/json');
    headers.set('x-id', await getVisitorId(this.#credentials));

    const token = await this.#credentials.get(SESSION_TOKEN_KEY);
    if (token) headers.set('Authorization', `Bearer ${token}`);

    const response = await fetch(request.url, {
      method: request.method,
      headers,
      ...(request.signal === undefined ? {} : { signal: request.signal }),
      ...(request.body === undefined
        ? {}
        : { body: typeof request.body === 'string' ? request.body : JSON.stringify(request.body) }),
    });

    const body = (await response.json().catch(() => undefined)) as T;
    return {
      body,
      headers: Object.fromEntries(response.headers.entries()),
      status: response.status,
    };
  }
}

export class ExpoSignalRTransport implements SignalRTransport {
  readonly #credentials: CredentialStore;
  readonly #connection;
  #startPromise: Promise<void> | null = null;

  constructor(
    credentials: CredentialStore,
    endpoint = SERVICE_ENDPOINTS.signalRHub,
  ) {
    this.#credentials = credentials;
    this.#connection = new HubConnectionBuilder()
      .withUrl(endpoint, {
        transport: HttpTransportType.WebSockets,
        skipNegotiation: true,
        accessTokenFactory: async () =>
          (await this.#credentials.get(SESSION_TOKEN_KEY)) ?? '',
      })
      .withAutomaticReconnect([0, 5_000, 10_000, 20_000, 30_000])
      .withHubProtocol(new MessagePackHubProtocol())
      .configureLogging(LogLevel.Warning)
      .build();
  }

  async invoke<T>(methodName: string, args: readonly unknown[]): Promise<T> {
    await this.#ensureStarted();
    return this.#connection.invoke<T>(methodName, ...args);
  }

  async close(): Promise<void> {
    this.#startPromise = null;
    await this.#connection.stop();
  }

  async #ensureStarted(): Promise<void> {
    if (this.#connection.state === 'Connected') return;
    if (!this.#startPromise) {
      this.#startPromise = this.#connection.start().finally(() => {
        this.#startPromise = null;
      });
    }
    await this.#startPromise;
  }
}

export class ExpoPasswordHasher implements PasswordHasher {
  sha256(value: string): Promise<string> {
    return Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, value);
  }
}

export class ExpoAppLifecycle implements AppLifecycle {
  onForeground(listener: () => void): Unsubscribe {
    return subscribeToAppState(listener, (status) => status === 'active');
  }

  onBackground(listener: () => void): Unsubscribe {
    return subscribeToAppState(listener, (status) => status !== 'active');
  }
}

export class ExpoClock implements Clock {
  now(): Date {
    return new Date();
  }
}

export class ExpoLogger implements Logger {
  debug(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void {
    console.debug(message, metadata);
  }

  error(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void {
    console.error(message, metadata);
  }

  info(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void {
    console.info(message, metadata);
  }

  warn(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void {
    console.warn(message, metadata);
  }
}

export function createExpoStorage(): KeyValueStore {
  return new ExpoKeyValueStore();
}

export async function saveSessionTokens(
  credentials: CredentialStore,
  sessionToken: string,
  refreshToken: string,
): Promise<void> {
  await Promise.all([
    credentials.set(SESSION_TOKEN_KEY, sessionToken),
    credentials.set(REFRESH_TOKEN_KEY, refreshToken),
  ]);
}

async function getVisitorId(credentials: CredentialStore): Promise<string> {
  const existing = await credentials.get(VISITOR_ID_KEY);
  if (existing) return existing;
  const generated = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  await credentials.set(VISITOR_ID_KEY, generated);
  return generated;
}

function subscribeToAppState(
  listener: () => void,
  predicate: (status: AppStateStatus) => boolean,
): Unsubscribe {
  const subscription = AppState.addEventListener('change', (status) => {
    if (predicate(status)) listener();
  });
  return () => subscription.remove();
}

export const REFRESH_TOKEN_KEY = AUTH_CREDENTIAL_KEYS.refreshToken;
export const SESSION_TOKEN_KEY = AUTH_CREDENTIAL_KEYS.sessionToken;
