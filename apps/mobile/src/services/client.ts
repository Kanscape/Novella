import { ApiClient } from '@novella/api-client';
import {
  createAuthenticationUseCase,
  createBookDetailUseCase,
  createCommentsUseCase,
  createDiscoveryUseCase,
  createReaderUseCase,
  createShelfUseCase,
  type AuthenticationUseCase,
  type BookDetailUseCase,
  type CommentsUseCase,
  type DiscoveryUseCase,
  type ReaderUseCase,
  type ShelfUseCase,
} from '@novella/client-core';

import {
  ExpoCredentialStore,
  ExpoHttpTransport,
  ExpoPasswordHasher,
  ExpoSignalRTransport,
} from '@/adapters/expo-runtime';

const credentials = new ExpoCredentialStore();
const http = new ExpoHttpTransport(credentials);
const signalR = new ExpoSignalRTransport(credentials);
let authentication: AuthenticationUseCase;
const api = new ApiClient(http, signalR, {
  refresh: () => authentication.refresh(),
});

export const discovery: DiscoveryUseCase = createDiscoveryUseCase(api);
export const bookDetails: BookDetailUseCase = createBookDetailUseCase(api);
export const comments: CommentsUseCase = createCommentsUseCase(api);
export const reader: ReaderUseCase = createReaderUseCase(api);
export const shelf: ShelfUseCase = createShelfUseCase(api);
authentication = createAuthenticationUseCase(
  api,
  new ExpoPasswordHasher(),
  credentials,
  signalR,
);

export { authentication };

export async function closeClient(): Promise<void> {
  await signalR.close();
}
