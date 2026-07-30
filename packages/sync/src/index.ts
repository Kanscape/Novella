import type { JsonValue } from '@novella/platform-contracts';

export const GIST_SYNC = Object.freeze({
  description: 'Novella App Sync Data (Encrypted)',
  fileName: 'novella_sync.json',
  schemaVersion: 1,
});

export const SYNC_CRYPTO_V1 = Object.freeze({
  algorithm: 'AES-256-GCM',
  ivBytes: 12,
  keyBytes: 32,
  pbkdf2Digest: 'SHA-256',
  pbkdf2Iterations: 100_000,
  saltBytes: 16,
  version: 1,
});

export interface EncryptedSyncEnvelopeV1 {
  data: string;
  iter?: number;
  iv: string;
  salt: string;
  v: 1;
}

export interface SyncModuleV1 {
  data: Readonly<Record<string, JsonValue>>;
  updatedAt: string;
  version: number;
}

export interface SyncDataV1 {
  appVersion: string;
  modules: Readonly<Record<string, SyncModuleV1>>;
  schemaVersion: 1;
  syncedAt: string;
  syncId: string | null;
}

export interface SyncCrypto {
  decrypt(envelope: string, password: string): Promise<string>;
  encrypt(plaintext: string, password: string): Promise<string>;
}

export function decodeEncryptedSyncEnvelopeV1(
  value: unknown,
): EncryptedSyncEnvelopeV1 {
  if (!isRecord(value) || value.v !== 1) {
    throw new Error('Unsupported encrypted sync envelope version.');
  }

  if (
    typeof value.salt !== 'string' ||
    typeof value.iv !== 'string' ||
    typeof value.data !== 'string' ||
    (value.iter !== undefined && typeof value.iter !== 'number')
  ) {
    throw new Error('Invalid encrypted sync envelope.');
  }

  return {
    data: value.data,
    ...(value.iter === undefined ? {} : { iter: value.iter }),
    iv: value.iv,
    salt: value.salt,
    v: 1,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}
