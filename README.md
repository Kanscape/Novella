# Novella

Novella is a third-party client for 轻书架.

The repository is being rewritten from Flutter to a TypeScript workspace:

- `apps/mobile`: React Native + Expo for Android and iOS.
- `apps/site`: React static website.
- `packages/*`: platform-neutral client core, protocol, sync, reader, and platform contracts.
- `apps/desktop`: reserved for a future Electron + React desktop client.

The previous Flutter implementation is preserved on the `archive/flutter` branch.

## Development status

The React Native rewrite is under active development. The application contract and data formats remain compatible with the existing LightNovelShelf service unless a migration note documents a change.

## Mobile development

The mobile app uses a local Expo development build for Android and iOS. EAS and
Expo Go are not part of the development workflow.

```bash
npm run prebuild --workspace @novella/mobile
npm run android
npm run ios
npm run dev:mobile
```

Run Expo CLI commands from `apps/mobile`, not the workspace root. For example:

```bash
cd apps/mobile
npx expo start --dev-client --clear
```

Starting Expo from the repository root makes Expo treat `novella-workspace` as
the app and falls back to `expo/AppEntry`, which cannot resolve the mobile
Expo Router entry.

## License

AGPL-3.0. See [LICENSE](LICENSE).
