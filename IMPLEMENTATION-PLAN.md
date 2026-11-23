# Final Project 3 implementation plan

Prepared November 12, 2026. Status: permanent Final-Project-3 workspace created. Mac text-journal foundation is implemented and evaluated; iPhone scaffolding exists but device/toolchain gates remain. See reports/STATUS.md.

## Product and architecture decision

Build Memory Catcher with the React scrapbook interface inside native Swift WKWebView shells for iPhone and Mac. Use a native journal service for storage, media, Apple Photos, calendar integration, weather and AI. Start with a Mac vertical slice and validate the same interface on iPhone early. React remains the presentation layer; a standard browser preview uses an explicitly separate fixture or browser adapter.

The initial release is a private, local-first Apple app. A hosted backend, public account system, paid AI provider and cross-device synchronization are optional later phases. Native integration does not make iOS background execution continuous. Cross-device sync is planned as an opt-in CloudKit private-database layer over per-device SQLite; never sync a live SQLite/WAL file through iCloud Drive. See `docs/milestones/CloudKit-cross-device-sync.md` for scope, conflict rules and provisioning gates.

Use the existing React app as a visual and interaction reference and the existing Swift package as a source of audited services. Build a fresh workspace and app identity. Bring over selected code with its tests and asset notices; do not copy build folders, credentials, personal journals, node_modules, Figma injection tooling or unfinished state. Neither predecessor is modified or used as the new app's live data directory.

## Experience requirements

- Text-heavy scrapbook pages remain readable, selectable and vertically expandable; photos are optional. Handwriting is for headings and short accents, with normal body typography for paragraphs.
- Each day has a primary text/audio/video composer, then Weather, Photos and Calendar context cards. Context cards reflow on phones and at large text sizes. A place-entry field and location tracking are not required.
- Request Photos and Calendar permissions only when their resource switches are enabled. Request microphone, camera and speech access in response to the corresponding action. Opening or resuming must not trigger new permission prompts.
- Capture originals first; analysis happens separately with visible progress, cancellation, retry and clear unavailable states. Recording means original audio/video, not only speech-to-text.
- Distinguish reported memories, uncertain visual clues, calendar plans and modeled weather. A default city's weather does not establish where someone was.
- Default summaries use concise, active first-person wording. State directly what the user did when the source supports it; avoid passive voice and filler such as “I said I visited” when “I visited” is supported. Preserve attribution when speaking itself matters, and never turn plans or uncertain clues into completed actions.
- Main navigation: Week, Find, Add, Settings. Put layout/export/review utilities in secondary controls. Preserve unfinished drafts across navigation and process termination.

## Proposed repository structure

```text
Final-Project-3/
  README.md
  AGENTS.md
  IMPLEMENTATION-PLAN.md
  apps/web/                   React, TypeScript, Vite, scrapbook UI
  apps/apple/                 Shared Swift host and platform entry points
    MemoryCatcher.xcodeproj/  iPhone and Mac targets
  packages/contracts/         Versioned JSON schemas and generated TS/Swift DTOs
  packages/JournalKit/        Audited native domain/storage/AI/vision/weather
  packages/JournalServices/   Native coordinator, permissions, jobs, OAuth
  fixtures/                  Synthetic journals and small licensed media
  scripts/                   Build, bundle, contract and acceptance commands
  docs/decisions/             Architecture and import decisions
  reports/                   Reproducible evaluation evidence
  THIRD-PARTY-NOTICES/
```

Decide package manager and compatible dependency versions in phase 0, pin a lockfile, and keep the new Vite configuration minimal. Production builds bundle local JS/CSS/fonts/images with a relative asset base. Production must not depend on a running Vite server or a sibling repository path.

## Service boundaries

| Layer | Owns | Initial implementation |
| --- | --- | --- |
| React | Navigation, forms, scrapbook presentation, playback UI, accessibility | Split the monolithic reference App into feature components |
| Bridge | Typed requests/responses, events, cancellation, media identifiers | WKScriptMessageHandler with a validated, versioned message protocol |
| Native journal | Entries, drafts, original media, revisions, source records, backups | SQLite metadata and managed media files in a new app data directory |
| Connectors | Permissions, Photos, Calendar, city weather, import/export | Native services with injectable adapters |
| Processing | Transcription, embeddings, summaries, grounded answers | Persistent job coordinator; Apple services first |
| Optional providers | Mac-hosted model or explicitly selected hosted model | Same capability contracts; disabled until configured |

React does not receive arbitrary filesystem paths, SQL execution, Keychain contents or OAuth refresh tokens. Use opaque media IDs and an allowlisted native media handler. Keep original-media bytes out of JSON messages. Prove image loading, MIME handling, seekable video/audio playback and large-file streaming before expanding the UI.

### Bridge contract

Envelope: `version`, `requestId`, `method`, `params`; replies include matching identifiers and either `result` or a stable error with `code`, readable `message` and `retryable`. Long jobs return a job ID and publish ordered progress events. Calls have deadlines and cancellation; completion is idempotent where a retry could create duplicate records.

Initial methods: `system.capabilities`, `journal.listDays`, `journal.getDay`, `journal.createEntry`, `journal.updateEntry`, `journal.deleteEntry`, `draft.get`, `draft.save`. Extend with `media.import`, `media.capture`, `photos.connect`, `photos.refresh`, `calendar.connect`, `calendar.refresh`, `weather.setCity`, `weather.refreshDays`, `analysis.enqueue`, `analysis.cancel`, `search.query`, `backup.export` and `backup.restore` as their phases land.

Capabilities report actual provider/device/permission availability rather than assuming all Apple hardware supports all models. Browser-only preview must explicitly report unavailable native features.

Accept bridge calls only from the trusted bundled main frame. Validate method names, payload sizes, schemas, revisions and source eligibility natively. Restrict navigation, send external links to the system browser, and prohibit untrusted remote pages from gaining bridge access. Render journal/OCR text as text rather than executable HTML. Enable a development-server bridge only in an explicit development configuration.

## Data and processing rules

- Native storage is authoritative. Do not maintain independent production IndexedDB and SQLite journals that can diverge. IndexedDB is a browser-preview adapter and an import source.
- Preserve UUIDs, occurrence date/timezone, original text and original media; support entries with only media. Track source identity/version, AI inclusion and revision separately from derived output.
- Native media uses protected, managed files plus transactional metadata, hashes, quota checks and recoverable staging. Sweep only verified unreferenced staged files after recovery. Export/restore must include originals and survive an interrupted operation.
- A job records source revision/digest, model and preprocessing versions, consent state, status and retry details. Save partial work incrementally but publish an artifact only after rechecking deletion, revisions and eligibility. Recover interrupted jobs without falsely marking them complete.
- Source edits/deletions, permission loss, AI exclusion and model changes invalidate affected artifacts. Keep deterministic summaries and keyword search available when models fail.
- Keep user-authored summary guidance and reusable people/event notes in native SQLite, separate from original memories. Link reference records to individual days explicitly; only linked records can clarify that day's references. Summary fingerprints include guidance and linked context, while grounding rules keep original memories primary and never treat a link as proof of attendance or an event.
- First import into an empty new vault from a copy of an export. Write separate adapters for the actual Swift snapshot variants and React `memory-catcher-json-v1`; validate media pairings, IDs, timezones and hashes. Never infer format compatibility from a filename.

## Automatic collection design

| Source | Initial behavior | Automation limit |
| --- | --- | --- |
| Apple Photos and videos | Initial bounded date-window scan, capture-date association, paginated/resumable import, change observation and resume reconciliation | Only authorized assets; limited access, iCloud availability and OS scheduling apply |
| New audio/video | Explicit capture or Share/file import, durable original save, then permitted processing | No passive microphone/camera recording or unrestricted reading of another app's files |
| Google Calendar | OAuth connection, initial sync, then incremental changes on launch/resume and bounded refresh while active | Native background refresh is best effort; always-running cloud sync needs a backend |
| City weather | User chooses city/timezone once; automatically fill relevant days and refresh incomplete recent days; per-day city override | No GPS tracking; historical modeled data and forecasts must be labeled |
| Google Photos | Optional Picker import, deduplicate selected media, capture-date association | Ordinary Picker access requires selection; do not promise unattended whole-library sync |

Photos start with the current journal window; offer explicit history backfill with progress, bounded batches and pause/resume. Do not decode every full-resolution photo at startup. Preserve source links and load/downscale pixels only for preview or analysis. Handle revoked/limited access and iCloud fetch cancellation.

Calendar uses the system authentication browser, appropriate registered app credentials and PKCE where required by the chosen Google client flow. Store refresh credentials in Keychain. Start with primary-calendar read access; add calendar selection with only the necessary additional scope. Honor recurring exceptions, deleted events, all-day dates, exclusive end dates, event timezones and multi-day association. Persist incremental sync tokens; recover expired tokens with a full refresh and respect query restrictions on incremental calls. Disconnect stops jobs and removes credentials. Calendar events remain plans.

Weather uses the existing Open-Meteo service as a starting point. Cache by place, date, timezone, provider and data basis; handle missing fields, rate limits, offline use and override changes. Establish service terms appropriate to release before public distribution.

## AI provider strategy

1. Apple Foundation Models for supported text generation; native Vision/Speech and compatible embedding providers for their separate tasks. Extract the existing consent, provenance and stale-result checks into services independent of SwiftUI.
2. Optional Mac-hosted model adapter, such as Ollama, behind capability probes. Text generation, visual understanding, embeddings and transcription are separate capabilities, potentially separate models. Benchmark synthetic cases before choosing a model size.
3. Optional hosted provider only after an explicit cost/data decision. No API secret in a frontend bundle and no silent cloud fallback. Connecting a Google account authorizes Google resources, not an unrelated AI model.
   - The user selected an OpenAI API-key provider for optional day/week summaries. The key is user-supplied, stored in native Keychain, and never returned to React. Enabling OpenAI summaries is a separate opt-in; only included evidence text and selected day context are sent. Raw media is not uploaded. OpenAI errors do not silently route to another provider.

On iPhone, localhost is the phone. Access to a Mac-hosted provider requires a running Mac and an authenticated private connection; it cannot silently rely on a Mac server always being available. A local companion service must restrict origins, authorization and exposure. Start provider integration on the Mac and leave phone remote access disabled until its connection design is implemented and evaluated.

Ground generated text in source IDs/excerpts, constrain output schemas, and validate references. Valid IDs do not prove factual correctness: evaluate supportedness with synthetic cases and human review. Defer a separate LLM judge, autonomous agent loop and multi-agent runtime until a specific product need is established.

## Implementation phases and exit criteria

Every phase follows plan, implement, evaluate. Record commands, fixture identity, results and limitations. A mock/injected provider result does not establish live native integration. Fix the failed phase before stacking dependent work.

| Phase | Deliverable | Required exit evidence |
| --- | --- | --- |
| 0 Foundation | Create Final-Project-3; copy this plan; new README/AGENTS; audit selected source; lock dependencies; separate demo data; establish new app identity and data directory | Fresh React build and minimal Mac host; capability report; toolchain inventory; no dependency on predecessor directories |
| 1 Bridge vertical slice | Bundled React in WKWebView, versioned contracts, native text-entry CRUD and drafts | Create, restart, read, edit, delete; contract mismatch/error/cancel cases; nested/external frame rejection; packaged offline launch; iPhone build and keyboard/navigation smoke check |
| 2 Durable media | Native managed originals, import/capture, playable media URLs, quota/staging/recovery, backup | Photo/audio/video save and playback after restart; seek video on device; export/restore originals with hash equality; interrupted save/recovery and quota behavior |
| 3 Photos automation | Toggle-only permission, incremental collection, capture dates, cloud opt-in, resumable backfill | Authorized/limited/denied/revoked fixtures; live synthetic Photos library import/change/delete; cancellation/duplicate prevention; no launch permission prompt |
| 4 Weather and Calendar | Default-city automatic days; Google OAuth/Keychain and incremental Calendar sync | Live chosen-city lookup and cached offline result; test-calendar create/change/delete; token renewal/revocation; all-day/DST cases; no attendance claims |
| 5 Apple processing | Durable jobs, local transcription, photo/video vectors, schema summaries and memory answers | Real supported-device model runs plus unavailable-device fallback; evidence and consent checks; source edits during jobs; no original modification; measured inference/memory budgets |
| 6 Optional model service | Explicit Mac provider configuration and task routing | Capability probe, synthetic inference, cancellation, unavailable-host recovery, invalid-output rejection and measured cost/resource profile; no surprise network fallback |
| 7 Parity and migration | Recaps, layout editing, archive import adapters, retained corrections and source links; date-aware past-journal import | Import journal text into matching historical days using explicit dates, then show already-authorized Photos and Calendar context for those days. Uncertain dates require review. Evaluate only with disposable synthetic archives and vaults; see [Past journal import](docs/milestones/Past-journal-import.md). Also verify restart/export/restore, long text with/without photos, keyboard, VoiceOver and phone large-text review; user reviews a concrete candidate before cutover. |
| 8 Optional extensions | WidgetKit, Share extension, scheduled backend sync, cross-device storage, and an AI memory interviewer | CloudKit private-database sync is selected for same-Apple-Account devices. It still requires registered bundle IDs, a configured container, signing entitlements, conflict/tombstone handling and two-device evaluation. The planned interviewer asks optional follow-up questions about a user-selected photo or calendar event and never saves answers without review. See the CloudKit and [AI Memory Interviewer](docs/milestones/AI-memory-interviewer.md) milestone documents. |

Preserve transcript corrections, per-memory AI control, summaries/recaps, search filters and original-source navigation when porting. Maintain a feature matrix rather than claiming parity from similar screenshots. Widget support stays on the roadmap and should use an app-group snapshot of approved display data when implemented. The AI memory interviewer is a future optional extension; see its milestone for behavior, privacy boundaries and acceptance gates.

### First implementation session

Create the new sibling directory only after the user starts kickoff. Copy this plan into its root and make a task log with phase 0/1 acceptance IDs. Inspect installed Node/package manager/Swift/SDK/Xcode and available resources without installing or changing global tools automatically. Extract only a clean scrapbook shell and native domain/storage slice. Generate shared contracts, wire `system.capabilities`, then save and reopen one synthetic text memory through the real bridge.

The initial app should offer a useful text-only journal before any Google credentials, model downloads or personal permissions are required. The next completed slice adds one synthetic photo and one short audio recording with playback.

## Toolchain and release gates

The current selected developer directory is `/Library/Developer/CommandLineTools`; a conventional Xcode installation was not found in `/Applications` during planning. A full supported Xcode, iOS SDK and suitable simulator/device are prerequisites for iPhone validation. Check for alternate installations at kickoff before treating installation as required. Mac command-line builds do not establish iPhone support.

Google Cloud API enablement, client registration and a designated test account/calendar are prerequisites for live Google testing. Begin with fixtures; configure accounts when that phase is ready. Do not treat this chat's connected MCP accounts as credentials available to the shipped app.

Release gates include local export/recovery, actual device media/permissions, model availability fallback, bounded processing, accessibility, asset notices, authorization revocation and fresh-install testing. Cloud sync, broad commercial rollout and App Store submission need their own final review after a working candidate exists.

## Decisions carried into kickoff

Defaults: React plus WKWebView; iPhone and Mac; native authoritative storage; no GPS; city weather; Apple Photos for automatic collection; Google Calendar read access; Google Photos Picker optional; Apple AI first; Mac-hosted AI optional; no required backend or paid model account; predecessor data migration opt-in.

Revisit only if device tests or concrete constraints justify it. Do not spend the initial session rebuilding every feature or producing another visual-only prototype.

## Technical references

- [WKScriptMessageHandler](https://developer.apple.com/documentation/webkit/wkscriptmessagehandler) and [WKURLSchemeHandler](https://developer.apple.com/documentation/webkit/wkurlschemehandler)
- [System authentication sessions](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [PhotoKit change observation](https://developer.apple.com/documentation/photokit/observing-changes-in-the-photo-library)
- [Foundation Models framework](https://developer.apple.com/foundation-models-framework/)
- [Google Calendar incremental sync](https://developers.google.com/workspace/calendar/api/guides/sync)
- [Google Photos API changes](https://developers.google.com/photos/support/updates)
- [Ollama API](https://docs.ollama.com/api/introduction)
- [Open-Meteo historical weather](https://open-meteo.com/en/docs/historical-weather-api)

Local references: Final-Project-2 `src/App.tsx`, `src/services/googleSync.ts`, `src/services/semanticSearch.ts`, `src/storage/journalDatabase.ts`; Final-Project `packages/JournalKit` and source asset notices. Planning is based on current source inspection, not older README completion claims.
