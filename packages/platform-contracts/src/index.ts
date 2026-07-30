export type JsonPrimitive = boolean | null | number | string;
export type JsonValue =
  | JsonPrimitive
  | JsonValue[]
  | { [key: string]: JsonValue };

export interface Clock {
  now(): Date;
}

export interface KeyValueStore {
  delete(key: string): Promise<void>;
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

export interface CredentialStore {
  delete(key: string): Promise<void>;
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

export interface HttpRequest {
  body?: JsonValue | string;
  headers?: Readonly<Record<string, string>>;
  method: 'DELETE' | 'GET' | 'PATCH' | 'POST' | 'PUT';
  signal?: AbortSignal;
  url: string;
}

export interface HttpResponse<T> {
  body: T;
  headers: Readonly<Record<string, string>>;
  status: number;
}

export interface HttpTransport {
  request<T>(request: HttpRequest): Promise<HttpResponse<T>>;
}

export interface Logger {
  debug(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void;
  error(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void;
  info(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void;
  warn(message: string, metadata?: Readonly<Record<string, JsonPrimitive>>): void;
}

export type Unsubscribe = () => void;

export interface AppLifecycle {
  onForeground(listener: () => void): Unsubscribe;
  onBackground(listener: () => void): Unsubscribe;
}
