# Community moderation rules

`manifest.json` is the stable client entry point. Each rules update must use a
new immutable `rules-<revision>.json` file and a strictly increasing numeric
`revision`.

## Rules schema

- `schemaVersion`: Parser contract version. Change only with a coordinated app
  update.
- `revision`: Numeric rules revision in `YYYYMMDDNN` form.
- `normalization`: `compact-v1` folds full-width ASCII and U+3000, applies
  Unicode lowercase conversion, and removes Unicode P/S/Z/C category
  characters.
- `scopes`: Fields where the rule is active. Supported values are
  `threadTitle`, `threadBody`, and `reply`.
- `clauses`: All clauses must match (AND).
- `anyOf`: At least one term in the clause must match (OR).

Terms use substring matching after normalization. Do not add regular
expressions. A term cannot be assembled across fields, but separate clauses may
match separate fields of the same submission.

## Publishing an update

1. Copy the current rules file to a new revision and edit the new file.
2. Update `manifest.json` with its revision, relative path, UTF-8 byte length,
   and lowercase SHA-256 digest.
3. Run `dart test test/community_moderation_assets_test.dart` from `site/`.

Do not add `expiresAt` unless the client and deployment policy are changed
together. Expiring the last valid rules file would disable all community
publishing during an extended site update outage.
