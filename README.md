# Hamna — هم‌نوا

Persian-first Flutter journal with a separate personal finance space.
This is an early source starter, **not a deployed app**. Flutter/Dart were not
available in the creation environment, so compilation, analysis, and tests have
not been run. Treat the first SDK run as an integration checkpoint.

## Included

- Persian right-to-left layout; warm cream and forest-green visual direction.
- Create/delete journal entries in session memory.
- Separate income/expense entry, EUR amounts, current Gregorian month totals,
  and category share bars. Money uses integer cents, including Persian digits.
- Product text in `lib/copy.dart`, separate from screen code for later localization.
- Unit tests for amounts and monthly aggregation.
- A voice capability interface. **No recording, transcription, or speech playback
  implementation yet.** The voice button is explicitly disabled.

## Run on a Mac with Flutter installed

```bash
bash scripts/bootstrap.sh
flutter run -d chrome
```

The script creates web platform files in a temporary SDK project and copies only
its `web/` directory here. It preserves this starter's source and tests.
It then runs dependency resolution, analysis, and tests. A web release uses
`flutter build web`; deploy `build/web` only after the integration checkpoints below.

## Current limits

Data disappear on refresh or app close. There is no authentication, Firebase
connection, synchronization, persistent audio storage, or public demo. Do not
use this starter as a permanent journal. EUR and Gregorian month grouping are
temporary defaults pending confirmation. There is no finance extraction from
voice, historical month selector, edit screen, or export yet.

## Before a public portfolio release

1. Confirm the repository URL, product name, currency, and calendar.
2. Run Flutter analysis, domain tests, and responsive checks on Mac and iPhone.
3. Test actual Persian speech capabilities on the target iPhone and Mac before
   choosing an implementation. Do not advertise support based on API presence.
4. Add Firebase Authentication and a repository adapter for Firestore;
   keep each user's journal and finance data in separate owner-scoped collections.
5. Test unauthenticated and cross-account access rejection with Firebase emulators.
6. Add persistent drafts, edit/delete, export, account deletion, and failure states.
7. Publish screenshots, setup instructions, architecture, and a demo with synthetic
   data. Keep personal entries, credentials, and service-account files out of Git.

## Planned hosting

Firebase **Hosting** for the static Flutter web build, with a project subdomain
instead of a purchased domain. Free quotas are limits, not a promise of unlimited
usage. No paid speech APIs, Cloud Functions, or Cloud Storage are assumed.
Firebase connection and deployment are intentionally not performed by this starter.

## References

- https://docs.flutter.dev/install
- https://docs.flutter.dev/ui/internationalization
- https://firebase.google.com/docs/hosting/quickstart
- https://firebase.google.com/docs/firestore/security/rules-conditions
