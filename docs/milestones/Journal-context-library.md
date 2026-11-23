# Journal context library

Status: implemented; web and Mac package builds pass; migration and model behavior not runtime-tested

## Goal

Create a native SQLite-backed journal context library for reusable summary preferences and user-defined people/events that can be linked to multiple days.

## Plan

1. Add a global summary-guidance preference and versioned person/event records to native SQLite, plus per-day links. Migrate existing journals forward without changing source entries or media.
2. Expose validated typed bridge methods for reading/writing guidance, managing reusable people/events, and linking/unlinking them to days. Keep SQLite authoritative.
3. Add Workshop forms for summary preferences and the reusable context library. Add a day-level picker to link relevant people/events to that day.
4. Add only linked context and the user’s summary preferences to native summary evidence. Keep original memories first; context can resolve references but must not invent attendance, chronology, relationships, or events. Include all context in the native cache fingerprint so edits refresh affected summaries.
5. Trigger automatic summary refresh after any guidance/context change. Evaluate web and Mac builds; use no personal journal data and do not add/run tests unless specifically requested.

## Acceptance checks

- User can save and later edit summary guidance in the native database.
- User can create/edit/delete reusable people and events and link the same item to multiple days.
- Daily/weekly summaries see the preference and only per-day linked context; original memories remain the strongest evidence.
- Changes invalidate affected generated summaries without changing originals or unrelated days.
- React cannot access SQLite directly; bridge validation, size limits, and native authority remain in place.
- Web and Mac package builds pass; no personal data is used.

## Implementation and evaluation (2026-11-17)

- SQLite schema 9 adds `journal_preferences`, `journal_context_items`, and `day_context_links`; schema migration is additive. Global guidance is limited to 2.5 KB. Reusable person/event notes have bounded fields, the library is capped at 250 items, and each day can link at most 12.
- Native bridge methods manage the guidance, library records, and day links with validation and revision checks. React never accesses SQLite directly.
- Workshop now edits summary guidance and reusable people/events. Each day has a picker for attaching relevant saved context. Removing a library record removes its links.
- Native summary evidence includes the global guidance and only that day's linked records. Apple and OpenAI instructions allow these records to clarify an original mention, while original memories retain priority and day links do not establish attendance or event occurrence. The evidence digest changes when guidance or linked context changes; manual summary overrides remain explicit overrides.
- `npm run build` passed. `npm run package` passed and produced a signed Mac app. SwiftPM emitted read-only user-cache warnings. A separate direct `swift build` invocation failed while writing the default Clang module cache under the restricted home directory; the project packaging script uses temporary module caches and completed successfully.
- No tests were added or run, per task instructions. No personal journal data was accessed. Database migration, live summary inference, and UI/device behavior remain unverified.
