# Future features from earlier versions

Reviewed November 12, 2026. This list compares `Final-Project` and `Final-Project-2` source/docs with the current `Final-Project-3` implementation. It omits capabilities already present in Project 3, including text/audio/video capture and uploads, Photos and Apple Calendar connections, editable day summaries, weekly summaries, configurable default weather, and adjacent-day navigation.

## Backlog

| Priority | Feature | Earlier implementation | Project 3 status / proposed work |
| --- | --- | --- | --- |
| 1 | Semantic search across photos and videos | Project 1 `JournalVision` used MobileCLIP embeddings with a persistent photo/video index and text-to-image queries. | First slice implemented for photos/videos added to a day: local Vision labels/OCR or sampled-frame clues are indexed by on-device sentence embeddings and searchable in the Photos & videos scope. Remaining: connected-library indexing, resumable batches, direct CLIP pixel embeddings, and Google Photos Picker import. |
| 2 | On this day | Project 1 generated local anniversary matches from saved memories, with settings to hide or restore dates. | The weekly section finds earlier saved dates matching the visible week. Per-date hide and restore controls are saved in native journal preferences; the hidden-date list is available from the section. |
| 3 | Monthly and yearly reviews | Project 1 had monthly/yearly recaps, date navigation, source-day links, empty-day options and text-copy preparation. | Month view now creates a first-person bullet synopsis from saved day summaries and pairs it with up to 12 representative photos when available. Bullets are cached in native storage against a source fingerprint and refresh when month content changes. Year view remains a saved-day projection; yearly narrative rollups, empty-day navigation, and reviewed copy/export remain. |
| 4 | Reviewable and shareable recap copies | Project 1 supported weekly/monthly/yearly and per-day copies, drafts, source-change review, reset and native sharing. | Not present. Add explicit user-authored copy drafts, source freshness checks and share/export after review. |
| 5 | Custom reflection prompts | Project 1 let users create, edit, remove and use writing prompts. | Not present. Add optional prompts in Workshop and offer one from the day composer without altering original memories. |
| 6 | Recording transcripts and corrections | Project 1 transcribed eligible audio/video on device and kept recognized and corrected text distinct. | Not present. Recording remains original audio/video; add optional on-device transcription with progress, permission/status handling, transcript editing and the existing AI opt-out. |
| 7 | Freeform scrapbook page layout | Project 1 supported moving/resizing/rotating/layering photos, text and decorations, plus undo/redo and saved layout drafts. | Not present. Add only after a bounded layout schema and backup/restore behavior are defined; source memories remain canonical. |
| 8 | Local backup, import/export and recovery bin | Project 1 exported/restored versioned snapshots, included recordings and offered recoverable deletion. | Not present. Needed before real-data migration or destructive bulk actions. |
| 9 | Weather detail card | Project 1 showed a city picker, per-day weather, historical basis and attribution details. | Per-day city overrides are implemented and saved in the native journal vault; the day card shows the active city and provider. Historical/forecast basis labeling remains. |
| 10 | Direct Google Calendar connection | Project 2 contained a Google sync setup and import/service code. | Project 3 currently reads calendars already synced to Apple Calendar. Add direct OAuth only with PKCE, Keychain token storage, incremental sync and disconnect cleanup. |
| 11 | Google Photos selected-media import | Project 2 researched Google Photos integration; Project 1's semantic photo index operated on linked photo/video sources. | Not present. Add user-selected import through the supported Google Photos Picker flow, then deduplicate and associate by capture date. |

## Additional future ideas

- **Create and share social media posts/stories:** let the user choose day memories and photos, draft a caption or story layout, review the exact content, then share through the platform's supported share flow. Keep posting user-initiated and require confirmation before anything is published. Not implemented.

## Product polish and behavior notes

- **Improve summary guidelines:** prioritize the user's saved memories and meaningful media details; reduce the prominence of calendar items and default-city weather in summaries.
- **Smarter calendar context:** select and summarize only calendar events that are likely relevant to the day, while clearly treating events as plans rather than proof of attendance.
- **Future dates:** improve the empty future-day experience and clarify how users can prepare or add to a future day without presenting it like a completed memory.
- **Persist compact summaries:** save small derived summaries and reuse them instead of reloading and regenerating them on every view. Invalidate cached summaries when source memories, media, calendar context, or summary rules change.
- **Visual polish:** improve color choices and contrast, revisit the app's displayed name/branding, and replace cheesy or overly sentimental lines with more natural copy.

## Work started: On this day

### Plan

- Derive date matches from the existing local day index; do not scan all journal bodies or contact an external service.
- Limit matches to earlier years for dates in the displayed week and to a small number of recent results.
- Show a short summary from AI-eligible text where available; otherwise use a neutral saved-memory count.
- Make each result open its original day. Do not add GPS/location tracking or make an empty/future day navigable.
- Evaluate the TypeScript production build and inspect the updated weekly page. This first slice does not add hide/exclusion persistence.

### Implementation

The weekly page now finds at most four earlier-year matches by month/day from the local day index. Each card opens the original day. Eligible written text supplies the excerpt; excluded or media-only days use neutral saved-memory counts. The section is omitted when the visible week has no matches. No new persistence or permission was added.

### Evaluation

`npm run build` passed (TypeScript and Vite). `npm run package` passed (web build, Swift host build, Mac app packaging and strict signature verification). The first package attempt overlapped with an in-progress SpeechJobs bridge signature update and reported a missing argument; a fresh package after the source settled passed. No personal journal content was read for visual evaluation. Hide/restore preferences and a synthetic anniversary UI walkthrough remain for a later slice.
