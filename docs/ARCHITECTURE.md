# Architecture

## Layers

- `main.dart`: Firebase boot, session authentication boundary and Persian theme.
- `screens/auth.dart`: sign-up, login and password recovery.
- `screens/journal.dart`: entry editor, search, pagination, mood and audio links.
- `screens/finance.dart`: independent ledger, monthly summaries and confirmation.
- `screens/home.dart`: responsive navigation, account tools and JSON export.
- `repository.dart`: all Firestore I/O bound to the current user's UID. Fixed document
  IDs plus transactions preserve creation timestamps when a save is retried.
- `domain.dart`: integer money parsing, monthly aggregation and deterministic voice
  suggestions. The UI never writes a voice proposal without user confirmation.
- `voice_composer.dart`: shared recording UI, transcript review and capability errors.
- `platform/browser*.dart`: conditional JS interop. Native stub has no false support.
- `web/browser.js`: MediaRecorder, live speech recognition, speech synthesis,
  IndexedDB clip storage, browser download and session drafts.
- `firestore.rules`: owner authorization and field validation, exercised by emulator
  tests with authenticated, anonymous and cross-account clients.

## Persistence and security

Journal path: `users/{uid}/journal/{id}`.
Finance path: `users/{uid}/transactions/{id}`.
Reads and deletes require UID ownership. Writes additionally validate known fields,
integer amounts, lengths, categories and timestamps. Admin SDK/service-account access
bypasses client Rules; this app contains neither. Session auth and disabled disk
Firestore cache reduce cross-account residue on a shared browser. Clips remain local
and are not encrypted separately from browser storage. Do not treat browser storage
as protection from another person with access to the same operating-system account.

## Zero-budget boundary

No paid speech API, Cloud Storage, Cloud Functions, AI classification or banking API.
Browser providers may process speech remotely. Audio is local only. Firestore text
sync and email/password Authentication require network access and respect Spark
quotas. GitHub holds source code and documentation, never private journal records.

## Failure behavior

No success message before a write is acknowledged. Timed-out operations may still
complete; stable IDs avoid duplicate records when retried. Permission denial and
unsupported speech leave typed entry available. Recognition ending does not silently
restart the microphone; recording continues visibly until stopped or the five-minute
limit. Navigation out of an active editor is blocked until recording stops. Cancel
and page hide release microphone tracks. Final and interim recognition are separate.

## Expansion

Add generated ARB resources and German UI translation, configurable currency without
mixing totals, account/data deletion, on-device model inference and native voice
adapters in later increments. Register native apps before changing target platforms.
