# Hamnava — هم‌نوا

A Persian-first, voice-oriented Flutter web journal with an **independent personal
finance workspace**. Warm cream surfaces, forest-green actions, copper accents,
responsive desktop navigation and mobile tabs.

## Implemented

- Email/password sign-up and login, sign-out, password reset, email verification.
- Owner-scoped Firestore journal: create, edit, delete, moods, tags, search and
  incremental history loading. Draft text stays in session storage until saved.
- Independent finance: income/expense, integer euro cents, categories, editable
  dates, month navigation, totals and category share charts.
- Live browser speech-to-text with Persian/German language selection and editable
  transcripts. Persian transaction suggestions from numeric or basic number-word
  sentences always require user review. This is deterministic parsing, not AI.
- Microphone recording, maximum five minutes per recording, with local IndexedDB
  clip storage, playback and download. Original audio **does not upload to Firebase**.
- Text-to-speech checks for a matching installed language voice and reports absence.
- JSON export of all journal entries and transactions, independently of pagination.
- Session-scoped auth, Firestore memory cache, owner-scoped Rules with field/type
  validation, browser capability tests, domain tests and emulator isolation tests.

## Continue in another chat

Read [the complete Persian handoff](docs/HANDOFF.fa.md) for goals, Firebase identifiers,
current deployment state, file map and a ready-to-paste prompt. Run
`bash scripts/preview.sh` to view locally, or `bash scripts/deploy-firebase.sh`
to build and publish after signing in to the project owner's Google account.

## Run locally

Requires Flutter **3.35+ / Dart 3.9+**; current stable Flutter is recommended.

```bash
git clone https://github.com/Rezatajali/hamnava.git
cd hamnava
bash scripts/bootstrap.sh
flutter run -d chrome
```

`bootstrap.sh` resolves dependencies, analyzes, tests and builds the web release.
The web platform files are included; no separate Flutter scaffolding is necessary.
If you already cloned the starter, run `git pull` before the commands above.

The web Firebase configuration for `hamnava-67a58` is already included. This is
public client configuration, not an admin credential. Never add service-account
keys to the repository. Analytics, Cloud Functions and Firebase Storage are not used.

## Firebase console prerequisites

1. Email/password provider enabled in Authentication.
2. Default Firestore database created in Standard edition (`europe-west3`).
3. Deploy the repository's `firestore.rules` after the emulator checks pass.
4. Keep the project on Spark without a linked billing account for the zero-budget
   plan. Usage is still subject to free quotas.

## Build, verify and host

```bash
flutter analyze
flutter test
flutter build web --release
node --test test-js/browser.test.cjs
npm install
npm run test:rules
```

Rules tests require Java 21+ and download the Firebase emulator. Tests use
`demo-hamnava`, not the live project, and never write personal live data.

For publishing on Firebase Hosting, install the Firebase CLI, sign in and then:

```bash
firebase login
firebase deploy --project hamnava-67a58 --only firestore:rules,hosting
```

Review the project ID before deploying. The Hosting URL is expected to be
`https://hamnava-67a58.web.app` **after a successful deployment**. No deployment has
been performed by this source update, so the URL is not claimed to be live.

The GitHub Actions workflow checks Flutter analysis, tests, web build, browser
logic and Firestore Rules. Inspect actual run results in Actions before using a
release; the workflow file itself is not evidence that those checks passed.

## Voice and privacy limitations

Browser speech recognition is not supported equally across Safari, Chrome,
iPhone and Mac. API availability does not establish Persian quality or offline
operation. The browser may send audio to its speech provider; no paid API is
configured by this app. Recordings remain on the local browser origin and will
not appear on a different device or localhost port. Clearing browser data may
erase them; download important clips. JSON exports include audio references,
not audio bytes. Unsaved recording references do not survive a page reload.

Speech recognition is for live dictation; arbitrary previously recorded audio
files cannot be transcribed by this implementation. Missing Persian TTS voices
are reported rather than replaced with an English voice. The finance dictation
parser is Persian-first; German dictation can be reviewed and amounts entered
manually. The interface remains Persian, with German UI localization deferred.

Transactions currently use EUR and Gregorian months. Native iOS/Android builds
need platform registration (`flutterfire configure`) and native voice adapters;
only the web target is configured in this version. This is an owner-isolated
backend, not end-to-end encryption. Firebase administrators retain administrative
access. Account deletion, budgets, imports, automatic bank sync and custom domain
setup are outside this first release.

## Verification at source publication

GitHub Actions [run 38370677298](https://github.com/Rezatajali/hamnava/actions/runs/38370677298)
passed Flutter analysis, domain/widget tests, the release web build, six browser
control-flow tests and three Firestore emulator isolation/schema tests for runtime
commit `28ed78f6a4617ea05ac5d3aa4d3ef9219ecfad10`. A seventh browser test covering
local audio persistence and microphone release also passes locally. Later changes
only update this evidence and add that test; application runtime code is unchanged.
Actual Safari/iPhone/Mac sign-in, synchronization, microphone quality and installed
Persian voices still require device acceptance testing. No live user data were used.

## Device acceptance checklist

- Create two accounts; journal and finance records from A never appear in B.
- Save a note, refresh, edit, sign out and sign in; verify persistence.
- Refuse microphone permission, test Persian dictation, pauses and recording stop.
- Record a clip; download and play it; test after refresh on the same browser.
- Check Persian TTS on the actual iPhone/Mac; show the unavailable state if absent.
- Dictate a financial sentence; correct the proposal; confirm month and totals.
- Export records beyond the first 30 notes; compare counts with Firestore.

See [architecture](docs/ARCHITECTURE.md).
