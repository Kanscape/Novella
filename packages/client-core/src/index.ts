import { ApiClient } from '@novella/api-client';
import type {
  AppLifecycle,
  Clock,
  CredentialStore,
  HttpTransport,
  KeyValueStore,
  Logger,
} from '@novella/platform-contracts';
import type { SyncCrypto } from '@novella/sync';
import { Telemetry, type TelemetrySink } from '@novella/telemetry';

export const APP_DISPLAY_NAME = 'Novella';

export interface ClientRuntimeDependencies {
  clock: Clock;
  credentials: CredentialStore;
  http: HttpTransport;
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

export function createClientRuntime(
  dependencies: ClientRuntimeDependencies,
): ClientRuntime {
  return Object.freeze({
    api: new ApiClient(dependencies.http),
    dependencies: Object.freeze(dependencies),
    telemetry: new Telemetry(dependencies.telemetry),
  });
}
