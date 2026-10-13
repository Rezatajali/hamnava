# Architecture and product direction

## Current starter

`main.dart` hosts the demo UI and ephemeral state. `domain.dart` contains journal
and transaction models, amount parsing, monthly totals, and the voice service
boundary. `copy.dart` owns Persian product text. No backend is active.

## Next implementation boundaries

- JournalRepository: drafts, entry persistence, edit, delete, export.
- FinanceRepository: independent transactions, currency, categories, month queries.
- VoiceService: runtime locale availability, permission, transcription, speech,
  cancellation and errors. Implement separately for web and native targets.
- Authentication: session lifecycle and per-user repository paths.
- Localization: replace copy map with generated ARB resources before adding German.

Proposed Firestore paths: `users/{uid}/journal/{id}` and
`users/{uid}/transactions/{id}`. Access requires the signed-in uid to equal the
path owner; validate schema and enforce this in Firestore Rules, not only in UI.
Add rules and emulator tests together before connecting a live database.

## Voice-first design goal

Journal: talk → transcript → review/edit → save. Finance: talk → proposed amount,
kind and category → explicit user review → save. These flows remain independent.
The current starter does not implement either voice flow.

Budget is zero. Never silently enable a paid provider. Browser/device speech
support, Persian quality, network requirements and privacy must be tested on
real devices. API availability alone does not establish offline operation.

## Portfolio deliverables

Readable public source, English README, Persian UI screenshots, architecture
notes, checks and a demo with synthetic data. Public repository choice does not
make journal records public: those belong in an authenticated private backend.
Original design direction: cream surfaces, deep green actions, restrained copper
details, spacious Persian typography. No third-party branded assets are included.
