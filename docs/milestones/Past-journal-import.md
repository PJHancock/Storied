# Past journal import and date assignment

Status: planned; not implemented

## Goal

Let the user import historical journal entries and have clearly dated entries appear on the matching past days. Once placed, an entry shares its day with any Photos and Calendar context already available for that date, so the week can be reviewed as a fuller historical record.

## Planned experience

1. The user explicitly selects journal files or a supported journal export and reviews a preview before import. The initial format list should prioritize plain text, Markdown, and structured exports; add other document formats only after their date and text extraction can be verified.
2. Split structured archives into entries using their explicit entry boundaries. Identify dates from unambiguous dates written in headings or entry metadata, preserving the original text and source order.
3. Automatically assign entries with a clear date to that local journal day. Put entries with missing, conflicting, or ambiguous dates into a review queue where the user can choose a date or leave them undated. Do not use file import/creation time as an occurrence date without telling the user and requesting confirmation.
4. Show a per-entry preview of the detected date and source evidence before committing. Allow the user to correct dates, skip entries, and cancel the batch.
5. After saving, use the same day view and weekly recap as other memories. Photos and Calendar details may appear for the assigned day only when those integrations are already enabled and have data for that date; importing an archive must not request permissions or trigger a live-library scan.

## Data handling and architecture

- The user initiates each import. Parse locally where supported; do not upload an archive to an AI provider for date extraction.
- Save imported text as user-authored original memories through native storage, with source filename, archive identity, detected date evidence, and content digest retained for provenance and duplicate checks.
- Keep React as presentation and use validated native bridge methods for parsing/import commit. Native SQLite remains authoritative; use transactional, revision-aware writes and recoverable batch staging.
- Preserve original text. Do not silently merge an imported entry into an existing entry. Detect exact duplicate content on re-import and offer skip/review behavior.
- Imported content remains subject to the existing per-memory AI inclusion controls. Do not generate summaries or change source permissions as a side effect of import.
- Never open or inspect predecessor live journals. Evaluate format adapters with disposable synthetic archives and synthetic vaults only.

## Acceptance gates

- Correctly dated synthetic entries land on the intended historical local day and remain there after restart and export/restore.
- Ambiguous, missing, conflicting, and timezone-boundary dates are presented for review rather than silently assigned. Import-time metadata is not mistaken for occurrence time.
- Preview, per-entry correction, skip, cancellation, duplicate handling, interrupted-batch recovery, and retry preserve originals without duplicate records or partial visible entries.
- Matching synthetic Photos/Calendar fixtures appear alongside imported memories only when their existing integrations are enabled; import requests no new permissions and changes no connected source data.
- Long Unicode text, multiple entries on one day, several days in one archive, and date formats supported by each adapter are evaluated with fixtures. Unsupported formats report that they are unavailable rather than importing broken text.
- The app builds for supported targets, and all import evaluation uses disposable synthetic data. Do not claim completion until the platform, restart, and recovery gates pass.
