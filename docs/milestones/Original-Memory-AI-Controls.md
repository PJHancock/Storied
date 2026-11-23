# Original-memory AI inclusion controls

Status: implemented; web and Mac packaging builds pass; live UI behavior not reviewed

## Goal

Let a user opt all original text memories on a day into AI summaries and local semantic search with one action, while retaining a separate on/off control on each memory.

## Plan

1. Put a bulk include/exclude button beside the day’s Original memories heading. If some or all entries are excluded, the button includes all; if all are included, it offers to exclude all.
2. Add an accessible per-memory action showing its current inclusion state and toggling only that entry.
3. Use the existing native `journal.updateEntry` revision check and authoritative `allowsAI` field so summary eligibility and local indexing continue to be enforced natively.
4. Refresh entries after bulk updates, invalidate automatic summaries through the existing revision flow, and report partial failure without hiding which records changed.
5. Evaluate with a production web build and Mac package build. Do not access personal data or add/run tests unless specifically requested.

## Acceptance checks

- Each original memory can be included in or excluded from AI summaries and local semantic search independently.
- The day-level action updates every original text memory and reports whether its action is to include or exclude all.
- Bulk updates use revision-checked native storage; local search removes excluded memories and indexes included memories through the existing native path.
- Browser preview does not gain write access.
- Web and native package builds pass; evaluation uses no personal journal data.

## Implementation and evaluation (2026-11-17)

- Added the day-level include-all/exclude-all button beside “Original memories” and a per-entry toggle showing each memory’s current AI/search inclusion state.
- Both actions call the existing revision-checked native update method. The native service remains authoritative and updates the semantic index from the saved `allowsAI` value. Bulk action reloads current day state after success or partial failure and reports the outcome.
- `npm run build` passed. `npm run package` passed and rebuilt/signed the Mac app. Existing EventKit deprecation and SwiftPM cache warnings were emitted.
- No tests were added or run. No personal journal data was accessed. A live UI interaction review and iPhone build/device check were not performed.
