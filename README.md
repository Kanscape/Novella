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

## License

AGPL-3.0. See [LICENSE](LICENSE).
