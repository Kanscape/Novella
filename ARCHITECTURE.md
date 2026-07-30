# Novella Rewrite Architecture

## Targets

- `apps/mobile`: Android and iOS through React Native and Expo.
- `apps/site`: the public website through React and Vite.
- `apps/desktop`: reserved for a future Electron and React client.

Expo native projects are generated with `expo prebuild` and are not committed.
Development builds are produced locally with `expo run:android` and
`expo run:ios`; this repository does not use EAS yet.

## Dependency Direction

```text
apps/mobile ----\
apps/desktop ----> client-core -> api-client -> platform-contracts
                 |           \-> sync -------> platform-contracts
                 |           \-> reader-engine
                 \------------> telemetry

apps/site --------------> public website code and public assets only
```

The shared packages contain no React, React Native, Expo, Electron, browser or
Node runtime imports. Applications own platform adapters and presentation.

## Compatibility Contracts

- Backend API origin: `https://api.lightnovel.life`.
- SignalR hub: `https://api.lightnovel.life/hub/api`.
- Refresh endpoint: `/api/user/refresh_token`.
- Gist filename: `novella_sync.json`.
- Sync schema: version 1.
- Encrypted sync envelope: version 1, AES-256-GCM, PBKDF2-HMAC-SHA256 with
  100,000 iterations, 32-byte key, 16-byte salt and 12-byte IV.

These constants and data shapes are preserved before implementations are
ported. Compatibility must later be verified against fixtures exported from
the `archive/flutter` branch.

## Platform Adapters

Mobile implements secure credentials, local storage, HTTP, lifecycle,
notifications, files and Turnstile WebView integration under `apps/mobile`.
A future Electron client implements the same ports under `apps/desktop`.
Neither implementation is imported by shared packages.
