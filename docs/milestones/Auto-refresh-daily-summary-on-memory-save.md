# Auto-refresh daily summary on memory save

Status: implemented; web and Mac packaging builds pass; live model inference not evaluated

## Goal

Regenerate and display a day's automatic summary when a new original text memory is saved with AI summaries enabled.

## Plan

1. Confirm the native summary evidence snapshot includes only memories with `allowsAI == true` and that its digest changes when an eligible memory is added.
2. Ensure the saved day becomes the active summary week when an Add drawer date changes, so its daily summary is included in the automatic summary job.
3. Clear stale in-memory manual-summary state when the native save invalidates the saved override; remove the matching week-card override too.
4. Keep the user's saved AI-inclusion choice authoritative. Excluded memories must not be sent; unchanged days should use their persistent cached summaries.
5. Evaluate the web build and Mac package build; use no personal data and do not add/run tests unless specifically requested.

## Acceptance checks

- Saving an AI-included original memory changes the eligible evidence fingerprint and triggers summary generation for that day automatically.
- The generated day summary becomes visible after completion, including when the memory was saved for a date outside the previously selected week.
- A summary override invalidated by native storage does not mask the generated result in the current UI.
- AI-excluded memories remain excluded from summary evidence; unchanged day summaries remain cacheable.
- Web and native package builds pass. No personal journal data is used.

## Implementation and evaluation (2026-11-17)

- A successful text-memory save now clears the UI's stale daily and week-card override state and selects the saved date's week. This covers adding a memory through the Add drawer when its date is outside the previously selected week.
- The existing source-key/revision flow refetches entries and starts the normal summary job. Native `SummaryJobs.evidence` filters to `allowsAI` entries, fingerprints eligible evidence, and reuses unchanged daily caches, so only a changed day's summary must be regenerated.
- The composer reports that an AI-included save is updating its summary. Excluded memories remain excluded by native evidence selection.
- `npm run build` and `npm run package` passed; the Mac app was rebuilt and signed. SwiftPM emitted its existing read-only user-cache warnings.
- No tests were added or run. No personal data was accessed. Live model inference and UI/device behavior were not evaluated.
