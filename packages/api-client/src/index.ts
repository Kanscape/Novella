import type {
  HttpRequest,
  HttpResponse,
  HttpTransport,
} from '@novella/platform-contracts';

export const SERVICE_ENDPOINTS = Object.freeze({
  apiOrigin: 'https://api.lightnovel.life',
  refreshTokenPath: '/api/user/refresh_token',
  signalRHub: 'https://api.lightnovel.life/hub/api',
});

export const SIGNALR_PROTOCOL = Object.freeze({
  name: 'messagepack',
  transferFormat: 'binary',
  version: 1,
});

export interface ApiRequest extends Omit<HttpRequest, 'url'> {
  path: `/${string}`;
}

export class ApiClient {
  readonly #transport: HttpTransport;

  constructor(transport: HttpTransport) {
    this.#transport = transport;
  }

  request<T>(request: ApiRequest): Promise<HttpResponse<T>> {
    return this.#transport.request<T>({
      ...request,
      url: `${SERVICE_ENDPOINTS.apiOrigin}${request.path}`,
    });
  }
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
