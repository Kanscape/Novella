import { ApiClient } from '@novella/api-client';
import {
  createAuthenticationUseCase,
  createBookDetailUseCase,
  createBookSearchUseCase,
  createClientSessionController,
  createCommentsUseCase,
  createDiscoveryUseCase,
  createHistoryUseCase,
  createProfileUseCase,
  createReaderUseCase,
  createShelfUseCase,
  type AuthenticationUseCase,
  type BookDetailUseCase,
  type BookSearchUseCase,
  type CommentsUseCase,
  type DiscoveryUseCase,
  type HistoryUseCase,
  type ProfileUseCase,
  type ReaderUseCase,
  type ShelfUseCase,
} from '@novella/client-core';

import {
  ExpoAppLifecycle,
  ExpoCredentialStore,
  ExpoHttpTransport,
  ExpoPasswordHasher,
  ExpoRequestIdentity,
  ExpoSignalRTransport,
} from '@/adapters/expo-runtime';

const credentials = new ExpoCredentialStore();
const requestIdentity = new ExpoRequestIdentity(credentials);
const http = new ExpoHttpTransport(credentials, requestIdentity);
const signalR = new ExpoSignalRTransport(credentials, requestIdentity);
const lifecycle = new ExpoAppLifecycle();
let authentication: AuthenticationUseCase;
const session = createClientSessionController({
  bootstrapAuthentication: () => authentication.bootstrap(),
  refreshAuthentication: () => authentication.refresh(),
  lifecycle,
  signalR,
});
const api = new ApiClient(http, session.transport, {
  refresh: () => authentication.refresh(),
});

export const discovery: DiscoveryUseCase = createDiscoveryUseCase(api);
export const bookDetails: BookDetailUseCase = createBookDetailUseCase(api);
export const bookSearch: BookSearchUseCase = createBookSearchUseCase(api);
export const comments: CommentsUseCase = createCommentsUseCase(api);
export const history: HistoryUseCase = createHistoryUseCase(api);
export const profile: ProfileUseCase = createProfileUseCase(api);
export const reader: ReaderUseCase = createReaderUseCase(api);
export const shelf: ShelfUseCase = createShelfUseCase(api);
authentication = createAuthenticationUseCase(
  api,
  new ExpoPasswordHasher(),
  credentials,
  signalR,
);

export { authentication };

export function startClient() {
  return session.start();
}

export function registerClientBackgroundTask(task: () => void | Promise<void>) {
  return session.registerBeforeBackground(task);
}

export function subscribeClientLifecycle(
  listener: (state: 'background' | 'foreground') => void,
) {
  return lifecycle.subscribe(listener);
}

export async function closeClient(): Promise<void> {
  await session.close();
}
