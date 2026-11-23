# Unified memory actions

Status: implemented; web and Mac packaging builds pass; live UI/device behavior not reviewed

## Goal

Place delete, applicable edit, and “Use for AI features” controls on the right side of each original memory card, covering text entries and uploaded/recorded media.

## Plan

1. Standardize a right-aligned action group in text and media cards. Keep text editing for text entries; show transcript editing only when recognized speech exists.
2. Move each media item's inclusion checkbox to the action group and label it “Use for AI features.” Preserve native opt-in semantics and existing local analysis behavior.
3. Add a revision-checked native transcript-edit method. It must require an AI-included non-photo recording, update the authoritative transcript revision, invalidate stale embeddings/summary overrides, then reindex through the native semantic index.
4. Keep media descriptions, OCR, and original binary files read-only in this flow. Text files imported by the composer remain normal text entries and use the text card actions.
5. Evaluate the React build and Mac package build without personal data; do not add/run tests unless requested.

## Acceptance checks

- Text entries show Delete, Edit, and an accessible “Use for AI features” toggle aligned on the right.
- Media entries show Delete and the same toggle; Edit appears only for a recording with recognized transcript text.
- Edited transcripts are saved natively with stale-revision protection, update summaries, and refresh local semantic indexing.
- Turning AI use off clears derived media text as the existing native behavior specifies; the original media remains saved.
- Browser preview remains read-only. Web and Mac package builds pass.

## Implementation and evaluation (2026-11-17)

- Text memory cards now place Delete, Edit and a labeled “Use for AI features” switch together on the right side. Uploaded/recorded media cards use the same right-side Delete and switch; Edit transcript appears only when recognized speech is available.
- Added native `media.updateTranscript` with analysis-revision validation, AI-inclusion checks and transcript size validation. It invalidates stale summary overrides and embeddings, then the host reindexes the changed transcript using the on-device semantic index. Original audio/video files are untouched.
- Uploaded text files continue to become ordinary text entries. Photo/video visual descriptions and OCR are not editable as transcripts.
- `npm run build` passed. `npm run package` passed and rebuilt/signed the Mac app. Existing EventKit deprecation and SwiftPM cache warnings were emitted.
- No tests were added or run. No personal journal data was accessed. Live transcript editing and iPhone/device behavior were not reviewed.
