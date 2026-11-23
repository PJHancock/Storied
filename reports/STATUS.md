## Move original memories between days (2026-11-19)

Text memories and user-uploaded photo, audio, and video attachments can now be moved from their day page with a destination date picker. Text uses the existing revision-checked entry update; media uses a new validated native `media.move` bridge method that updates its SQLite day index and metadata while retaining the same ID and managed original file. A moved memory opens on its destination day. Moves invalidate day summary overrides for both dates, and a moved selected uploaded photo carries its headline selection when the destination has no existing choice. Automatically connected Photos-library items remain external context and are not moved by this control.

Evaluation: `npm run package` passed, including the TypeScript/Vite build, Swift build, and signed Mac app package. SwiftPM emitted its existing read-only user-cache and deprecation warnings. No tests or synthetic-vault UI review were run; interaction, moved-media playback, and summary refresh across both days remain visually/runtime unverified. No personal journal or library permission was used.

## Image headline and weekly layout breathing room (2026-11-19)

The weekly spread can now promote one suitable photo day into an image-led card. It selects the day with the most displayed images, breaking ties in favor of shorter source text and summary detail; manually edited titles/details or custom photo placement/size keep their current text-first layout. The hero image fills the card frame without cropping, and its date remains overlaid and readable. The hero card omits its generated weekly headline/subheading, and other multi-image cards can omit their generated subheading. Day pages retain the complete generated or saved text, and page-edit mode keeps text visible. Content-aware balancing assigns the hero card extra height and rebalances the week across the two pages.

Evaluation: `npm run build`, `npm run package`, all 29 web tests, and all 44 native tests passed. Synthetic tests cover photo-headline choice, preservation of custom text/layout, photo-count and content tie-breaking, and extra height in page balancing. No personal journal or Photos permission was used. The packaged app was not opened for a synthetic visual review; image fit, weather label overlap, and text readability with real photos remain unverified. No phase completion is claimed.

## Photo-forward weekly scrapbook spread (2026-11-19)

Weekly day cards now display a larger lead image and a compact strip of extra unique photo/video previews from the same date. Extra images are included only when another past day has no visible photo, and the spread never shows the same asset identifier twice. PhotoKit video items and uploaded video previews receive a Video label. Existing selected headline photos remain first. The spread uses already-cached Photos previews and saved upload previews; it does not broaden the scan on page entry. Synced Photos previews can now contribute additional images, up to four visuals on one day card and seven total across the week. Content-aware page balancing accounts for the extra image strip, while the existing page editor and date navigation remain available. Photo frame sizes were increased for desktop and mobile layouts.

Evaluation: `npm run build` and `npm run package` passed; all 44 native tests and 26 web tests passed. Synthetic web coverage checks scarcity-based extras, no duplication, one-per-day behavior when every day has photos, headline-photo priority, video type/date retention, and future-day handling. No personal journal or Photos permission was accessed. The packaged app was not opened for live visual inspection, so the final fit with real previews and long card text still needs a desktop UI review. SwiftPM reported its existing read-only cache/deprecation warnings. No phase completion is claimed.

## Desktop journal backup and separate-copy restore (2026-11-19)

Added Workshop controls to create a verified directory backup, restore that backup into a new separate journal folder, and open a validated restored folder in a separate app instance. Backups use a consistent SQLite online snapshot and include saved memories, drafts, page edits, summary/cache data, and managed original uploads/previews. Each database/media file is recorded with size and SHA-256 and verified on restore. Restore checks SQLite integrity, validates attachment records, disables Photos and Calendar connections in the copy, and leaves the open journal untouched. Restore has to be explicitly opened; it does not silently replace the current journal. The bridge exposes no filesystem paths to web content and is unavailable in browser/iOS builds.

The settings explain that backups are unencrypted folders, can contain cached Photos and Calendar details, omit Keychain API keys and the browser-stored default weather city, and require Photos/Calendar to be reconnected after restore. Native storage remains authoritative; browser React only starts the native file-picker operations. A standalone WAL-mode SQLite snapshot is opened in immutable read-only mode for integrity checks so validation does not depend on sidecar files.

Evaluation: all 44 native tests and 22 web tests passed; `npm run build` and `npm run package` passed and rebuilt the signed Mac app. Synthetic-vault tests cover WAL-backed drafts, entries, page edits and media bytes across restore, disabled copied Photos connection, source-vault preservation, tampered/missing media cleanup, invalid manifest paths and nested destinations. No personal journal, Photos/Calendar permission, or external data was used. The desktop picker flow and visual interaction were not exercised in a live UI; opening the restored app instance remains an unverified runtime integration. No phase completion is claimed.

## Integrated individual-day edit control (2026-11-19)

The individual-day page's Edit page action now sits in the day header beside previous/next navigation, matching the weekly page's integrated edit trigger. Its editing controls open in a header-anchored panel, and the former separate toolbar row is removed. The trigger remains stationary while editing; Save & close uses the existing revision-checked save, and Cancel still discards draft edits.

Evaluation: `npm run build` passed, including the TypeScript check and production Vite build. No tests or synthetic-vault visual review were run; rendered panel placement and keyboard interaction remain visually unverified. No personal journal data or library access was used.

## Week-to-week day-card variety and tilt (2026-11-19)

Automatic day cards now rotate through the eight available paper/color treatments using a deterministic week offset, so each week gets a different mix while all seven dates use distinct styles. Cards also receive seven rotating tilt angles with both positive and negative lean. Saved per-day card-style choices remain in effect; photo placement, ordering and content are unchanged. Reduced-motion settings continue to remove transforms.

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt and signed. SwiftPM emitted existing read-only user-cache warnings. No tests or synthetic-vault visual review were run; actual treatment balance and overlapping photos remain visually unverified.

## Save when closing weekly edit tools (2026-11-19)

The weekly spread’s edit-tools toggle now saves the current page draft and exits page editing when activated from the open tools panel; its label communicates “Save & close.” The explicit Cancel button still discards unsaved edits. This uses the existing native revision-checked page-text save path.

Evaluation: `npm run build` and `npm run package` passed. No tests or UI review were performed; no personal journal data was accessed.

## Automatic day-card spacing and equal spread height (2026-11-19)

On desktop, the two scrapbook pages now stretch to one shared height, with a viewport-based minimum. Each page's day grid fills the space left by its heading, weekly recap and footer; its rows divide that space automatically. The phone layout keeps its existing vertical scrolling. The production type check also exposed and fixed an extra JSX brace in the page-editor toolbar conditional.

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt and signed. SwiftPM emitted existing read-only user-cache warnings. No tests or synthetic-vault UI review were performed; actual spacing with long text, photos, editing controls and narrow viewports remains visually unverified.

## Summary source links (2026-11-19)

Completed daily and weekly generated summaries now offer View summary sources with the referenced original writing, recognized speech, user media clues, connected-photo clues/count, calendar plans, selected-city weather, linked context and summary guidance as applicable. Source links navigate to and focus the relevant saved memory, recording, calendar item, photo or appropriate section; ambiguous photo descriptions open the Photos section rather than guessing. Source list copy distinguishes uncertain photo clues and calendar plans. User-edited summaries/headings do not claim generated-source attribution.

The trusted native bridge resolves only IDs cited by the selected completed summary job, checks that its native evidence snapshot remains current, and rejects unknown jobs/scopes. Excluded/deleted original entries and media are absent from the native evidence; host filtering hides photo/calendar sources after permission loss, excludes hidden matching photos and hidden weather, and reports unavailable references. Matching cached PhotoKit clues link to an individual asset only when one visible matching photo is identifiable. No new permission is requested and nothing is sent to a provider to view sources.

Evaluation: npm run package rebuilt/signed the desktop app; all 41 native and 22 web tests passed. Synthetic native coverage exercises daily/weekly source scoping, invalid jobs/scopes, running-job rejection, excluded memories, deletion and stale-summary rejection. Host permission filtering, photo matching, browser navigation/focus, keyboard interaction, live Photos/Calendar, and visual rendering remain unverified; the browser access host was unavailable in the preceding review. No personal journal, live model or personal library was used. iPhone/device gates remain open; no phase completion is claimed.

## Preview and reset scrapbook layouts (2026-11-19)

The page editor now has Preview layout / Continue editing, an unsaved-changes indicator, and separate Reset day layout and Reset week layout controls. Preview hides editing outlines and selection controls, keeps the draft, and applies the same content-aware spread balancing used after saving. Reset day removes only that day's card style and photo placement/size; Reset week removes those layout overrides for all seven days plus the custom day order. Both operate only on the unsaved draft and offer Undo reset; Save page commits through the existing native revision check and Cancel reloads saved edits. Text edits, original memories and headline-photo selection are retained.

Evaluation: npm run package rebuilt/signed the desktop app; all 22 web tests passed, including synthetic checks that reset preserves text and unrelated days, restores day order only at week scope, and supports undo and order-independent dirty detection. No personal data or interactive visual/keyboard UI review was used; the browser access host was unavailable in the preceding review. Actual rendered preview, long text and narrow viewport behavior remain unverified. Device gates remain open.

## Content-aware weekly spread balance (2026-11-19)

The weekly spread now estimates the rendered weight of each day's headline, subheading, written content, selected photo size and placement, and the weekly recap. It compares 3/4/5-day left-page splits against the two-column card layout, including full-width cards, while retaining the saved day order, card styles and photo choices. Empty weeks keep the existing four-day split. The current split stays stable while resources reload and while the user is editing; balance is recalculated after the updated content or saved page edits settle. This is a deterministic estimate, not a measurement of actual rendered heights.

Evaluation: npm run package rebuilt/signed the desktop app; all 19 web tests passed, including synthetic heavy-left/heavy-right balance, empty/default behavior, input order preservation and deterministic output. No personal journal/library or live UI review was used. Actual fit with varied screen sizes, fonts, zoom, extreme text and photos remains unverified; the browser access host was unavailable in the preceding review. No phase completion is claimed.

## Per-day photo placement and size (2026-11-19)

The week page editor now exposes independently selectable photo placement (automatic, above, beside, overlap) and size (automatic, small, medium, large) for the selected day, with immediate preview. Choices save/cancel with the revision-checked per-week page record and survive reopening; Automatic removes just the corresponding override. Native validation accepts only allowed choices for dates in that week. The existing headline-photo selector chooses which photo to show; these settings control its presentation only and do not change source media, card style, photo selection or AI evidence. Whole-image fitting is retained. No visual UI or personal-library review was performed, and side-by-side/overlap placement on narrow widths and accessibility remain unverified.

Evaluation: npm run package rebuilt/signed the Mac app. All 40 native tests and 16 web tests passed. Synthetic storage coverage verifies persistence/restart, independent reset, invalid choices, out-of-week dates and revision conflicts. Browser access was unavailable in the preceding UI review; iPhone/device gates remain open.

## Per-day card style choice (2026-11-19)

The week page editor now offers eight card styles for the selected day, with immediate preview and an Automatic option that removes that day's override and restores the existing weekday-based treatment. Explicit styles also expand compact empty days so the choice remains visible. Style choices are stored in the existing native, revision-checked per-week page-edit record and save/cancel together with text and ordering. Native validation restricts styles to the supported names and dates to the selected week. Existing source memories, photo placement and summary evidence are unchanged; content-aware style suggestions are not yet implemented.

Evaluation: npm run package rebuilt/signed the Mac app; all 39 native tests and 16 web tests passed. A synthetic native test covers persistence across restart, reset of one style without affecting other edits, invalid styles/out-of-week dates, and conflicting revisions. No personal library or journal was used. Visual and keyboard interaction remain unverified because the browser access host was unavailable in the preceding review; iPhone/device gates remain open.

## Scrapbook layout and page-editor corrections (2026-11-19)

Day cards now use a separate Select day button in page editing mode, with editable text outside an interactive card button. Edit-mode subheadings expand instead of truncating text. Normal navigation remains a full clickable day button and its accessible label includes a custom headline. Photo format selection uses measured thumbnail proportions with a safe fallback and deterministic variation; all frames use contain so the whole image is visible. Long-text card sizing accounts for all written entries for the day. The existing colorful paper palette and order are retained.

Evaluation: npm run package rebuilt/signed the desktop app and all 16 web tests passed, including synthetic portrait, landscape and square format checks. An isolated browser-preview review was attempted, but the browser access host was unavailable. Keyboard, screen-reader and rendered photo/layout behavior remain unverified; no personal data or library permissions were used.

## Colorful scrapbook cards (2026-11-19)

Restored distinct colorful paper fills across weekday styles, including sage, clay, butter, blue and lavender. Compact day tabs use the same palette; existing shapes and forced-colors support remain. npm run package passed and rebuilt/signed the desktop app. No visual review or personal journal access was performed.

## Scrapbook day-card variety (2026-11-19)

Added seven weekday-stable paper treatments inspired by index cards, lined notes, tickets, postcards and tags. They share existing typography, colors, focus and responsive sizing; compact empty days remain small tabs and selected/photo controls continue to work. A synthetic Superdesign draft was created for visual direction; the shipped app uses local CSS and existing photo treatments. No private journal or Photos assets were used for design.

Evaluation: npm run package rebuilt/signed the Mac app; all 15 web tests passed. No interactive visual review or personal-library access was performed, so visual fit with long text, photos, page editing, and narrow widths remains unverified.

## Rearrange days from the weekly page editor (2026-11-19)

The existing Edit page toolbar now supports selecting a day card and moving it earlier or later in the week. The full seven-day order is saved atomically with that week’s page-text edits, restored when the week is reopened, and discarded by Cancel. The responsive 3–5 day split and photo-format assignment follow the saved order. Native storage validates that a submitted order is exactly a permutation of the seven dates for that week.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host compile, signed Mac app). No tests or UI walkthrough were run; interaction and persisted ordering with a synthetic vault remain unreviewed.

## Full page text editing (2026-11-19)

Added a single Edit page toolbar on week/day pages, replacing the separate edit button inside the weekly recap and the day heading editor. Edit mode makes week headings/subheadings, page notes/labels, weekly recap heading/body, day headlines/subheadings, and day section headings editable directly within the existing layout. Day headline/detail fields are shared between week cards and day pages. Save commits all edited fields atomically to native SQLite preferences with a revision check; Cancel discards the draft and reloads the saved version; Reset selected text removes that field's page override. Blank fields and paragraph breaks are supported. Native key/value and payload limits reject malformed or oversized requests. Page text overrides are presentation edits, independent of original entries, source caches, AI evidence and generated summaries; source updates therefore preserve them. Existing original-memory edit controls remain available for changes to source writing. Generated dates/counts, controls, status messages and synced calendar contents retain their original meanings.

Page navigation and automatic/manual sync are guarded while the page editor is active. Saved edits survive process restarts and concurrent-window conflicts are reported without overwriting. Browser preview shows the page but saving requires the native app.

Evaluation: npm test passed all 38 native tests, including page-text persistence, reset, revision conflict rejection, invalid fields and independence from source updates. All 15 web tests passed. npm run package passed and rebuilt/signed the desktop app. No personal journal/library, live provider, or interactive UI review was used. In-place caret behavior and narrow-width layout remain visually unverified. No phase completion is claimed.

## Varied day-card photo layouts (2026-11-19)

Week date cards now assign each available photo preview a stable visual treatment based on its day and selected source: pinned print, wide landscape crop, square crop, or framed postcard. Consecutive photo cards avoid repeating the same treatment, while retaining the original photo and existing alt text.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host compile, signed Mac bundle). No automated tests or UI walkthrough were run; crop/placement behavior across varied synthetic images and compact screens still needs visual review.

## Month and year review projections (2026-11-19)

Extended Dates & review with All days, Month, and Year views. The month/year projections show saved-day and memory totals and list the matching source days; selecting a date opens the original day page. The view is derived from the native saved-day index and does not generate or edit memories. Narrative rollups and shareable reviewed copies remain future work.

Evaluation: `npm run build` passed, including TypeScript checking and production Vite build. No tests or UI walkthrough were run. No personal journal, Photos, or Calendar data was accessed; month/year behavior with a synthetic vault remains visually unreviewed.

## Cached monthly photo synopsis (2026-11-19)

Expanded Month review with a first-person bullet list built from each day's saved summary override or local source preview, plus up to 12 representative connected or uploaded photo previews. Connected-photo dates are considered across the selected month when Photos is already enabled; this review flow does not request permission. Monthly bullets are saved in native journal preferences with a source fingerprint covering entry revisions, uploaded-media content/analysis, connected photo IDs/clues/counts and day-summary overrides. The saved bullet list is reused until that fingerprint changes; photos are loaded for display from their existing native sources. Year review remains a date/count projection.

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt/signed. No tests or synthetic-vault UI walkthrough were run. No personal journal or Photos/Calendar data was accessed; image loading, monthly duration and content quality remain unreviewed. Photos remain dependent on prior explicit Photos connection and cached/iCloud availability.

## Hide and restore On this day dates (2026-11-19)

Completed the next planned On this day slice. A user can hide an anniversary card from the weekly section; the original saved day is unchanged, and the preference applies to future matching weeks. A collapsed Hidden dates list allows restoring any hidden date. The hidden-date list is persisted in native journal preferences and validated as calendar dates. Browser preview displays the section but disables persistence controls.

Evaluation: `npm run build` passed. `npm run package` passed and rebuilt/signed the Mac app, compiling the app and JournalServices dependency. A standalone `swift build --package-path packages/JournalServices` attempt failed before compilation because Swift could not write its user-level Clang module cache; the package build succeeded with the project script. No tests, UI walkthrough, or synthetic-vault review were run; no personal journal or Photos/Calendar data was accessed.

## Adaptive weekly scrapbook spread (2026-11-19)

The week spread now defaults to four days on the left page and three on the right. After week context loads, the split can move within a 3–5 day range when available image previews make another distribution more balanced; weeks without images retain the 4/3 default. Past days with no saved memories, summary detail, or available photos remain visible as compact date tabs, preserving navigation while reserving page space for content.

Evaluation: `npm run build` and `npm run package` passed; the Mac app bundle was rebuilt and signed. No tests or UI walkthrough were run. Split behavior with varied synthetic image distributions and responsive layouts remains visually unreviewed.

## Per-day weather location overrides (2026-11-19)

Added native journal-preference storage and bridge methods for a location override per day, with validation for the city name and coordinate ranges. The day Weather card now lets the user look up and set a city for that date or clear the override to use the default city. Week weather context and manual refresh resolve each day's saved override, so summaries use the matching place and existing weather cache keys distinguish cities. No GPS or source permission is involved. Updated the future-feature list; historical/forecast-basis labels remain future work.

Evaluation: `npm run build`, `swift build --package-path packages/JournalServices`, and `npm run package` passed; the Mac app was rebuilt and signed. SwiftPM reported existing read-only user-cache, deprecation, Sendable, and framework search-path warnings. No UI review or native-vault integration walkthrough was performed; no personal journal, Photos, or Calendar data was accessed. Existing per-day overrides use the current `journal_preferences` table, so no schema migration was needed.

## Apply saved summaries without preview flash (2026-11-19)

Week cards, the weekly recap, and the day heading now show a compact Loading saved summary indicator while native source validation/cache lookup is pending, instead of briefly rendering an extracted fallback heading. Missing summaries switch to Creating summary during actual generation. Previously validated saved summaries remain visible when returned with an updating job; terminal failures still permit source previews. Reduced the extra hook scheduling delay from 1500 ms to 100 ms after sources are ready. Weekly editing is disabled until a saved/fallback summary has resolved. Layout reserves space around loading copy.

Evaluation: npm run package passed and rebuilt/signed the desktop app; all 15 existing web tests passed. No personal data or live UI/provider review was performed. This removes 1.4 seconds of intentional scheduling delay; total load time still depends on source validation, PhotoKit, weather and actual generation. No measured UI latency claim is made.

## Fluid source sync and reusable summaries (2026-11-17)

Implemented a native per-selection summary coordinator with serialized model calls and preference for the most recently viewed selection. React no longer cancels jobs on navigation. Identical running evidence reuses its job; source/model fingerprints govern cache reuse rather than refresh counters or presentation-only photo IDs. The fingerprint format advances to version 9, so older results require one regeneration. Valid prior summaries are served while updating only if every cited source remains eligible; deletion/exclusion removes old display eligibility. Each validated daily result is committed immediately, survives subsequent weekly failure, and is reused after restarting. Weekly recaps still use original included evidence. Calendar plan evidence now reads actual cached event details, so edits to an existing event affect the fingerprint.

Weather results are stored in native SQLite preferences by city/date/units/version, reused for 24 hours, deduplicated while in flight, and retained on offline reads. Manual sync forces a refresh. Photo batches reuse unchanged asset versions (preview and Vision clues), retain previous previews while batches progress, and reconcile removed asset IDs at completion. All authorized previews can be synced, while summary visual evidence remains explicitly bounded to 12 previews per day; this resolves the >12-preview request validation mismatch. Opening the week preserves existing context during reload and summary generation waits for the newly requested context snapshot to settle. Stale checks run on launch/focus/visibility and each minute while visible; stale connected days use the manual sync path, which cancels running jobs across weeks and blocks new summaries until sync finishes. Background work here means while the desktop process is open, not closed-app execution. Cancelled jobs in other weeks resume from saved daily results when that week is revisited.

Evaluation: npm run test:web passed 15 tests; npm test passed 36 native tests, including duplicate running-request reuse, navigation survival, persistence through weekly failure/restart, exclusion removing old summaries, and weather persistence. npm run package rebuilt/signed the desktop app. No personal library, journal, live OpenAI call, or UI walkthrough was used. Existing SwiftPM cache and EventKit warnings remain. iPhone/device gates remain open. Initial display still waits for native source validation; job scheduling is in process, with completed results durable across restarts. This does not claim all phase acceptance gates complete.

## Pause summaries during week sync (2026-11-17)

Starting the week sync now cancels a running summary job and gates new summary starts until all photo/video, calendar and weather refresh work finishes. The progress indicator reports that summaries are paused. Once sync completes and the refreshed source snapshot is ready, normal cache validation resumes and only stale summaries regenerate.

Evaluation: desktop packaging passed. No tests or personal source access were used.

## Bound initial Photos day loading (2026-11-17)

Opening a day now requests at most one uncached Photos preview instead of up to 12 sequential previews, each of which can wait for iCloud and run local Vision analysis. A previously synced cached photo set is still returned in full; users can load all available previews with the week sync action. This bounds the slow work most likely to exceed the 120-second bridge deadline without removing automatic day context.

Evaluation: `npm run build` and `npm run package` passed. SwiftPM emitted existing read-only user-cache warnings. No live Photos/Calendar permissions or personal library data were used, so runtime load times remain unmeasured.

## Editable weekly summary (2026-11-17)

Added a compact Edit button to the weekly summary. The user can edit its heading and text, save an override specific to the displayed week in native SQLite preferences, or restore the automatic summary. Removed the direct memory link from the summary panel because all days are already on the week page.

Evaluation: `npm run build` and `npm run package` passed. SwiftPM emitted existing read-only cache, deprecation, and Sendable warnings. No synthetic-vault UI review or personal journal data was used.

## Summary footer and OpenAI completion handling (2026-11-17)

Moved week summary progress into the bottom-right footer next to Sync week, with compact spinner, elapsed time, stage/cancel controls and Retry summary after failure/cancellation. Day status remains visible above the reader. OpenAI summaries previously had a 500-token cap and parsed output text before checking response completion. Increased the allowance to 4000 tokens, reject explicitly incomplete responses before parsing, join output text parts, and distinguish truncation, refusal, invalid JSON and invalid evidence references. Grounding validation remains required. The exact reason for the reported live failure is unknown because its response was not captured; truncation is a plausible cause, not a confirmed diagnosis. Larger output allowances can permit additional billed generation.

Evaluation: npm test passed all 33 native tests, including three synthetic response parser checks for completed multipart text, truncated output and refusal. npm run package passed, rebuilding/signing the desktop app. No API key, personal data, live provider call, or visual UI review was used.

## Visible summary generation status (2026-11-17)

Added a prominent status banner to week/day views with a spinner, elapsed time, source-loading versus generation stages, native per-day/weekly recap progress, cancellation, and terminal error text. Elapsed time measures the current loading/generation phase and is not a completion estimate. Native generation retains its existing 180-second deadline; source loading happens before that deadline starts. No live provider speed measurements are available.

Evaluation: npm run package passed and rebuilt/signed the desktop app; all 15 existing web tests passed. No personal journal access or live provider/UI check was performed; tests do not exercise the new timer visually.

## Planned past-journal import and date assignment (2026-11-19)

Added a future import feature that places clearly dated journal entries on historical days, allowing already-enabled Photos and Calendar context for those days to appear alongside them. The plan includes preview, date evidence, review for ambiguous dates, duplicate handling, local/native storage, and synthetic-only evaluation. Import must not request source permissions or inspect predecessor live journals. This is planning only; no importer was implemented.

## Restore normal sizing for empty past days (2026-11-19)

Removed the compact day-tab treatment from past dates with no saved memories. They again use the regular empty-day card size, weekday paper styling, headline and invitation text. The spread-balancing estimate now accounts for those normal-sized cards so it does not lay out the week as if they were tiny tabs. Saved day order, explicit card styles, and photo settings are unchanged.

Evaluation: `npm run build` and `npm run package` passed. No tests or live UI review were performed; no personal journal data was accessed.

## Planned AI memory interviewer (2026-11-19)

Added a future optional feature to the roadmap: an AI interviewer that asks user-controlled follow-up questions about a selected photo or calendar event to help capture specific recollections. The milestone defines source grounding, user review before saving, calendar-plan versus attendance handling, privacy/provider boundaries, and synthetic-vault acceptance gates. This is a planning change only; the feature is not implemented.

## Browser viewport responsive layout (2026-11-19)

The scrapbook now follows the live browser viewport height, uses fluid page widths and outer spacing, and has wider but still bounded reading pages on desktop. The existing narrow-screen navigation/layout remains in effect, with bottom safe-area spacing for phones. Content can continue scrolling when it exceeds the window height.

Evaluation: `npm run build` passed. No tests or UI review were performed; no personal journal data was accessed.

## Hide completed generation note on weekly summary (2026-11-19)

Removed the completed weekly summary status blurb that described its generator and asked the reader to review the result. The live generation status and cancel control remain visible while a summary is running. Daily summary status behavior is unchanged.

Evaluation: `npm run build` passed. No tests or UI review were performed; no personal journal data was accessed.

## Content-based media card titles (2026-11-17)

Uploaded audio cards now use the opening words of the saved transcript as their title; photos and videos use saved visual analysis, falling back to transcript when available. Titles are shortened for readability, update automatically as saved content changes, and show the original upload filename beneath them. Before analysis or transcription exists, the upload filename remains the title. The original media files and native storage names are unchanged.

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt and signature-replaced. SwiftPM emitted existing read-only user-cache warnings. No tests or live UI review were performed, and no personal media or journal data was accessed.

## Week sync placement (2026-11-17)

Moved Sync week into the right page footer inside the weekly book spread, aligned to the bottom right next to the year/memory count. Progress stays beneath the button and wraps within the page. Removed the detached panel below the book. npm run package passed and rebuilt/signed the Mac app. No live UI or personal journal review was performed.

## Week sync button and complete preview batches (2026-11-17)

Added a bottom-of-week sync button for the displayed week. Manual sync walks elapsed days sequentially, fetching all authorized Apple Photos image/video previews in batches of 12, refreshing Calendar and weather, and reporting loaded versus matched counts, disconnected sources, and individual failures. Native SQLite accumulates each batch; completed partial results remain available and the next manual sync retries unavailable previews. Regular metadata sync preserves previously cached previews. PhotoKit thumbnail requests have a six-second deadline, cancel late requests, ignore degraded callbacks, and resume their continuation exactly once. Weather requests bypass HTTP cache and have a 15-second timeout. Originals remain in Apple Photos; video results are poster previews, not imported playable videos. No source permission is requested implicitly.

Evaluation: npm run test:web passed (15 tests); npm run package passed, compiling TypeScript and the Swift host and rebuilding/signing the desktop app. Existing web tests do not exercise PhotoKit. No personal library or live journal was accessed. Live iCloud previews, library mutation during pagination, and device UI behavior remain unverified; this does not complete the Photos automation acceptance gates.

## Original-memory delete confirmation placement (2026-11-17)

The original text-memory Delete button now opens its confirmation directly beneath the button in the memory header. It overlays long memory content instead of appearing after it, so confirmation stays immediately available without scrolling. Keep memory closes it; permanent deletion behavior is unchanged.

Evaluation: `npm run build` and `npm run package` passed. SwiftPM emitted existing read-only cache warnings. No UI review or personal journal data was used.

## Video duration loading for visual analysis (2026-11-17)

Visual analysis now loads AVFoundation duration asynchronously instead of reading the deprecated synchronous property, and supplies the saved video MIME type when opening the vault's extensionless `.bin` file. This lets AVFoundation identify the container before sampling frames. If a malformed or unsupported video still cannot be inspected, analysis reports that visual analysis is unavailable while preserving the playable original.

Evaluation: `npm run package` passed and rebuilt/signed the Mac app. SwiftPM emitted existing read-only cache and deprecation warnings. No synthetic video fixture was available for an end-to-end analysis check; no personal media was accessed. iOS/device behavior remains unverified.

## Per-day headline photo selection (2026-11-17)

The day view now lets the user choose a connected Photos image or uploaded photo as that day's week-card headline image, and restore automatic selection. The selected photo ID is persisted in native SQLite preferences and is validated against that day’s cached Photos items or uploaded assets; deleting/hiding the selected image clears the choice. Week cards use the selected image when available, while original media remains in its existing source/storage.

Evaluation: `npm run build` and `npm run package` passed. SwiftPM printed existing read-only user-cache warnings. No UI review or personal Photos library/journal data was used; photo-choice persistence and week-card rendering were not exercised against a synthetic native vault.

## Week cards for summarized days (2026-11-17)

Week cards now use a filled colored entry style when the day has original memory content or a non-empty summary detail, including connected-photo summaries. Days with no substantive summary remain invitation cards with the dotted outline.

Evaluation: `npm run build` passed. No UI review or personal journal data was used.

## Live dictation and cursor insertion (2026-11-17)

Dictate text now uses native `SFSpeechAudioBufferRecognitionRequest` with partial results and `requiresOnDeviceRecognition`; the React draft updates as recognition arrives. The insertion range is captured from the draft textarea when dictation starts. Final/interim text replaces that range, so a caret inserts in the middle or end and a selection is replaced. Discard restores the pre-dictation draft. Permission requests remain tied to the explicit Dictate text action; audio and video recording flows are unchanged.

Evaluation: `npm run build`, the configured JournalServices build, and `npm run package` passed; the Mac app was rebuilt and signature-verified. No microphone/Speech permission prompt or live recognition was exercised, no tests were added or run, and iPhone/device behavior remains unverified.

# Collapsible OpenAI API key entry (2026-11-17)

Workshop no longer displays the password field by default. It shows “Add API key” before setup and “Replace API key” after setup; either opens the entry form with Verify and Cancel controls. Successful verification closes the form and keeps the key in Keychain. The configured summary and visual-understanding switches remain visible independently.

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt and signature-verified. No tests or UI review were performed.

# First-person daily and weekly summaries (2026-11-17)

Apple Intelligence and OpenAI summary instructions now require a first-person journal voice, referring to the journal owner as I/me/my rather than they/he/she. Source references are recast only when they clearly refer to the journal owner; other people remain distinct, and no thoughts or actions are invented. Deterministic web previews likewise use first-person phrasing, including for connected-photo clues and count-only photo summaries. Summary cache fingerprint version 7 invalidates previously generated third-person summaries.

Evaluation: `npm run build`, all 15 web tests, and all 30 native tests passed. Tests cover first-person fallback phrasing and correction of a vague generated heading. No live Apple Intelligence/OpenAI summary generation was run, so model adherence to the first-person instruction remains unverified.

## macOS upload-file picker (2026-11-17)

The upload button already triggered the bundled HTML file input, but the macOS WKWebView host did not implement WebKit's open-panel delegate callback; macOS therefore treated file selection as cancellation. Added a trusted-main-frame-only `NSOpenPanel` handler, including multiple-selection support and filters for accepted image, audio, video, plain-text, and Markdown files. The existing native media import and text-file draft flows are unchanged.

Evaluation: `npm run package` passed and rebuilt/signed the Mac app. A disposable synthetic-vault UI smoke attempt did not reach the picker because the review instance timed out on an earlier native bridge operation and left the composer disabled, so file selection/upload was not observed end-to-end. No user file was selected or imported. iOS 17 relies on WKWebView's built-in Safari-style file selection; no iOS device/UI check was available.

# Journal context library (2026-11-17)

Added a native SQLite-backed summary-guidance field and reusable person/event context library. Workshop manages the global guidance and context records; each day can explicitly link relevant people/events from the library. Only linked records are passed to that day’s summary. Apple and OpenAI summary instructions allow them to clarify a name/reference from original memories while preserving original-source priority and avoiding claims of attendance or event occurrence from a link alone. Summary evidence fingerprints include the saved guidance and linked records, so automatic summaries refresh when these inputs change. The native database remains authoritative; SQLite migration is additive (schema 9).

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt and signed. SwiftPM emitted read-only user-cache warnings. A separate direct Swift build was blocked writing to the default home-directory module cache; the project package script's temporary-cache build succeeded. No tests were added or run, and no personal journal data was accessed. Migration, live model inference, and UI/device behavior remain unverified. See `docs/milestones/Journal-context-library.md`.

## Unified memory actions (2026-11-17)

Text memory cards now show right-aligned Delete, Edit and “Use for AI features” controls. Uploaded and recorded media cards show Delete and the same inclusion toggle; an Edit transcript button appears only when recognized speech exists. Transcript edits use a native revision-checked method, remove stale search embeddings, save the text with native storage, and reindex it locally. The original media is unchanged. Uploaded text files are normal text entries; OCR and visual descriptions are not editable through transcript controls.

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt and signed. Existing EventKit deprecation and SwiftPM cache warnings were emitted. No tests were added or run. No personal journal data was accessed; live UI/transcript behavior and iPhone/device behavior remain unverified. See `docs/milestones/Unified-memory-actions.md`.

## Connected Photos produce daily summaries (2026-11-17)

Connected Photos are now enough to create a daily heading and subheading even when no original text or user-added media exists. When uncertain visual clues are available, Apple Intelligence/OpenAI may summarize them with explicit “Photos may show” qualification. When only the connected-photo count is available, the app generates “A day in photos” with a count-based subheading and makes no claim about image contents. Calendar/weather-only days retain the blank-subheading invitation. Summary cache fingerprint version 6 invalidates summaries made under the previous photo-only invitation behavior; this supersedes the earlier context-only rule for days with connected Photos.

Evaluation: `npm run build`, all 15 web tests, and all 30 native tests passed. Synthetic checks cover visual-clue summaries, count-only summaries, and invitations when photos are absent. No personal Photos library, live model output, or packaged UI was used or reviewed.

# Automatic daily-summary refresh on memory save (2026-11-17)

After an original text memory is saved, the UI clears its in-memory daily/week override that native storage invalidates, selects that memory’s week, and refetches the source snapshot. The existing summary hook reacts to the updated source fingerprint and regenerates the changed daily summary automatically. This also works when the Add drawer saves to a date outside the previously selected week. Native evidence generation still filters by `allowsAI`; excluded memories are not sent, and unchanged summaries remain cached. The save status indicates that an included memory’s summary is updating.

Evaluation: `npm run build` and `npm run package` passed; the Mac app was rebuilt and signed. Existing SwiftPM read-only user-cache warnings were emitted. No tests were added or run, no personal data was accessed, and live model/UI/device behavior was not evaluated. See `docs/milestones/Auto-refresh-daily-summary-on-memory-save.md`.

## Original-memory AI inclusion controls (2026-11-17)

On each day, the “Original memories” heading now has a bulk control: it adds every original text memory to AI summaries and local semantic search if any are excluded, and offers bulk opt-out when all are included. Each memory has its own stateful toggle. Both actions use the existing revision-checked native entry update; native storage remains authoritative and keeps local embeddings in sync. A bulk update reloads the day after success or partial failure and reports its result. Browser preview remains read-only.

Evaluation: `npm run build` passed. `npm run package` passed and rebuilt/signed the Mac app. Existing EventKit deprecation and SwiftPM cache warnings were emitted. No tests were added or run. No personal journal data was accessed; live UI interaction and iPhone/device behavior remain unverified. See `docs/milestones/Original-Memory-AI-Controls.md`.

## Recent past weather routing (2026-11-17)

Recent dates up to seven days before the device-local date now use Open-Meteo Forecast API with `past_days=7` and `forecast_days=16`; returned daily data is selected by matching the requested ISO date. Older dates continue to use the historical archive endpoint, while today/future dates retain the forecast route. This avoids requesting the previous few days from the delayed reanalysis archive.

Evaluation: `npm run build` passed. Updated the existing `.build/Memory Catcher 3.app` web assets and verified its ad-hoc signature. No live Open-Meteo call or automated test was run; restart the app to load the updated bundle.

Weather request fix (2026-11-17): a live request reproduced HTTP 400 because the today/future branch combined `forecast_days` with explicit `start_date`/`end_date`, which Open-Meteo rejects as mutually exclusive. Removed `forecast_days` from that branch; the equivalent Provo request then returned HTTP 200 with the requested date. Recent-past `past_days=7&forecast_days=16` also returned HTTP 200. Corrected the day-card temperature label from °C to °F to match the requested API units. A stale dictation status conditional in `MediaComposer` also failed TypeScript compilation despite that function accepting only audio/video; removed the impossible branch so the package could build. `npm run package` passed and rebuilt/signed `.build/Memory Catcher 3.app`. No UI walkthrough or personal data was used; relaunch the app to load the fix.

# Optional OpenAI visual understanding (2026-11-17)

Added an independent Settings toggle for OpenAI visual descriptions alongside the existing OpenAI summary toggle. The API key remains in native Keychain. With visual understanding off, uploaded media uses the local Apple Intelligence/Vision path. When enabled, uploaded photos are resized and video analysis sends at most three sampled, resized frames to GPT-6 Luna; it does not upload the original video or audio. Connected Photos-library assets are excluded. Descriptions are marked as uncertain, retain local Vision clues, and feed the local semantic index. API failures keep the original and report the failure, with local Vision fallback when available.

Evaluation: `npm run build`, `swift build --package-path packages/JournalServices --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX27.2.sdk`, and `npm run package` all passed. The package script built and signed the Mac app. Existing compiler deprecation/Sendable warnings were emitted. No tests were added or run for this request. No key, real media, personal journal, or Photos permission was used, so live provider behavior and output quality remain unverified; no iPhone/device build or UI runtime review was performed. See `docs/milestones/Optional-OpenAI-Visual-Understanding.md`.

## OpenAI API key and summaries (2026-11-17)

Added an OpenAI key entry in Workshop. The key is verified through `GET /v1/models`, stored in native Keychain with device-only accessibility on iOS, and never returned to the web UI. Key storage is separate from the default-off “Use OpenAI for summaries” setting. When enabled, the existing summary pipeline uses OpenAI Responses API (`gpt-6-luna`) with strict structured output and the existing source-grounding validation. Only AI-included evidence text and selected day context are sent; raw photo/audio/video bytes are not uploaded. OpenAI failure is surfaced without silently switching providers. API verification does not send journal content.

Desktop evaluation: `npm run build`, `bash scripts/prepare-ios.sh`, `swift build --package-path packages/JournalServices`, and `npm run package` passed. Packaging uses the installed macOS 26.5 Command Line Tools SDK and omits the unavailable Foundation Models visual attachment path, retaining local Vision label/OCR fallback. The resulting `.build/Memory Catcher 3.app` was packaged and signature-verified. A disposable `.build/Memory Catcher 3 Desktop Review.app` was opened against an empty synthetic vault at `/private/tmp/memory-catcher3-openai-desktop-review-20261117`; Workshop visibly includes the OpenAI key field and summary controls. The field is empty (the visible `sk-…` is its placeholder), OpenAI is unconfigured, and the verify button is disabled. No API key was entered, no live OpenAI calls were made, and no personal journal or library was accessed. No tests were run. Full Xcode, iPhone SDK, and `simctl` remain unavailable, so iOS compilation, signing, installation, and device/Keychain behavior are unverified. No public release occurred. See `docs/decisions/0012-openai-api-key-summaries.md`.

Weekly-summary source fix (2026-11-17): the weekly provider now receives the full eligible source snapshot directly, including original written memories and recognized speech, instead of only the shorter daily summaries. Source IDs therefore remain tied to originals through weekly generation. The weekly cache fingerprint version was advanced so summaries created by the old daily-summary pipeline are regenerated. `npm run package` passed and the updated signed desktop review copy reopened successfully against the empty synthetic vault. No live provider call or personal-vault review was performed; the blank review vault cannot demonstrate user-specific summary output.

Persistent Photos/Calendar context (2026-11-17): schema 8 stores each day's connected PhotoKit previews and EventKit results in native SQLite. Per-day reads use the local cache for up to 24 hours, then refresh it; Workshop adds “Sync this week now” for an immediate refresh, and an active desktop app refreshes the displayed week every 24 hours. The cache stores at most 12 resized Photos previews per day plus event details; it does not copy full Photos-library originals. User-uploaded media remains in the journal's existing managed storage. `npm run package` passed. Workshop's sync control was visually verified in the isolated review copy; it was correctly disabled while Photos and Calendar were disconnected. Manual sync execution, live Photos/Calendar permission behavior, and library change detection were not exercised; no tests or personal-library access were performed. The 24-hour timer is best-effort while the app is open; closed-app background execution and iPhone scheduling remain unimplemented/unverified.

Empty-context cache invalidation (2026-11-17): per-day cache snapshots now record whether Photos and Calendar were connected when queried. A previously cached empty day is invalidated as soon as a connection is enabled, so the app performs a fresh native fetch rather than preserving empty data for the full 24-hour TTL. Older cache records without source flags are invalidated on read. `npm run package` passed; no live personal-library query or test was run.

Recent Photos previews (2026-11-17): changed the 12-item PhotoKit day preview limit to fetch newest-first, so a manual sync prioritizes today's latest shots. `npm run package` passed. Full Photos-library import remains out of scope; cache/review behavior was not exercised against a personal library.

Photos empty-state diagnosis (2026-11-17): the day screen now distinguishes zero date-matched Photos items from a nonzero library count with no visible previews, where items may be hidden or thumbnail loading failed. Limited-library access continues to be called out. `npm run package` passed and rebuilt/signed the desktop app. No personal Photos library was inspected; live permission state and preview behavior remain unverified.

Native operation timeout during Photos sync (2026-11-17): the bridge gave `resources.sync` the generic 15-second deadline even though a week sync can fetch up to 12 previews per day, and Photos preview generation requested full-resolution image data before downscaling. Sync now has a five-minute deadline and single-day Photos reads have two minutes; timeout copy says the request may still be running and advises checking before retrying. PhotoKit now requests a 240 px rendition directly, and local Vision analysis runs off the main actor. `npm run package` passed and rebuilt/signed the desktop app. No tests or personal Photos access were used; real iCloud fetch latency and live sync completion remain unverified.

Speech no-speech segment handling (2026-11-17): Apple Speech error 1110 is now treated as an empty segment so silence inside a longer recording does not discard speech recognized in other 30-second segments. If all segments are silent, the job reports that no speech was detected and confirms the original recording remains saved. `npm run package` passed. No microphone, personal recording, or live speech recognition was used; automated tests were not run.

Photos timeout follow-up (2026-11-17): traced the remaining long workload to week-context loading, which requested full per-day Photos results for all seven days concurrently. The week view now requests one newest preview per day; manual/24-hour sync refreshes calendar details and photo counts without downloading previews; up to 12 previews load only for the selected day. Count-only cache snapshots are marked incomplete and cannot be reused as a full preview cache. Timeout messages now name the operation. npm run package passed and rebuilt/signed the desktop app. No tests or personal Photos access were used; live iCloud latency remains unverified.

# First slice status

## Inline context removal controls (2026-11-17)

Replaced the Photos, Calendar and Weather context-card removal labels with small inline “×” buttons beside each item. Accessible labels and hover titles retain the removal meaning; the hidden-weather “Restore weather” action remains a text button. No native storage or source-library behavior changed.

Evaluation: Vite production bundling passed. `npm run build` stopped at TypeScript checking with errors in `apps/web/src/App.tsx` (missing `photoLibraryCount`) and `apps/web/src/bridge.ts` (generic result cast); neither points to the edited JSX, and no baseline comparison was performed. No UI/device review was performed.


## TypeScript build follow-up (2026-11-17)

Made the summary context mapping explicitly use the shared `SummaryContext` type, including its required `photoLibraryCount` field. Clarified the browser-preview `resources.day` generic result cast through `unknown`, since runtime method narrowing cannot narrow the generic result type. `npm run build` passes, including TypeScript checking, Vite production bundling and web asset finishing. At that point, `npm run package` could not complete under the selected Command Line Tools. This was later resolved for desktop packaging using the installed macOS 26.5 SDK; see the OpenAI API key and summaries evaluation at the top of this report.

## Individually removing automatic context items (2026-11-17)

Photos, calendar events and daily weather can now be removed from an individual journal day. Dismissals are stored in the authoritative SQLite journal, keyed by day, source and item ID; Photos and Calendar remain untouched in their source libraries. Weather can be restored from its day card. Dismissed context is omitted from automatic summaries. Schema 6 adds the dismissal table.

Evaluation: `npm run build` passed; `npm run package` compiled and signed the Mac app; `npm run test` passed all 23 native tests, including dismissal persistence and source/day isolation. No personal journal or library access was used. `npm run test:web` had 11/12 passing; the remaining assertion still expects a calendar event title (“Planned: Dentist”) in a summary preview, while the existing privacy behavior intentionally reduces calendar evidence to a generic uncertain-plan signal. The first unrestricted `swift test` attempt could not load Swift Testing macros under the selected CommandLineTools; the configured project test script succeeded. No iPhone build or live UI/device check was performed.

## Persistent generated summaries (2026-11-17)

Native SQLite schema 7 now stores generated daily and weekly summaries with SHA-256 fingerprints of their exact eligible evidence and context. On revisit, unchanged summaries load from SQLite. When a day changes, only that day's summary is regenerated; the weekly summary is refreshed, while unaffected daily summaries are reused. Fingerprints include source IDs for Photos and Calendar plus the total date-matched Photos count, so new connected items invalidate the cache even when their private details are not passed to the model. Edited headings remain separate saved overrides.

Evaluation: `npm run build` passed; `npm run test` passed all 24 native tests, including reopen/reuse and changed-day regeneration using injected providers. Real model generation was not exercised. The subsequent desktop package and UI verification are recorded at the top of this report; iOS device behavior remains unverified.

## Summary source priority and context invitations (2026-11-17)

Daily summary prompts for Apple Intelligence and OpenAI now require the title and lead sentence to come from original writing or recognized speech, then use photo/video clues, calendar, and weather as lower-priority context. Generic headings such as “Unclear Activity” are corrected to a heading from the primary source. If there is no original writing or recognized speech, the app uses a deterministic “Add your perspective” summary that qualifies any visual clues, describes calendar/weather only as context, and invites a note, audio, or video. Empty days use the same invitation. Summary fingerprint version 3 invalidates older auto-generated headings.

Evaluation: `npm run build`, all 13 web tests, and all 26 native tests passed. Tests cover priority ordering, context-only invitations, and replacement of a vague generated title. No real Apple Intelligence or OpenAI inference was run. The referenced visual provider is now present, and the current desktop package and UI verification are recorded at the top of this report. iOS build/device behavior remains unverified.

## Context-only heading variations (2026-11-17)

Days without original writing or recognized speech now show one of eight invitation headings selected consistently by day. The summary subheading stays blank, even when photos, calendar events, weather, or unprocessed media are available. The SQLite summary fingerprint version advanced to 4 so earlier context-only text is not reused.

Evaluation: `npm run build` passed, all 13 web tests passed, and `npm run test` passed all 27 native tests, including stable per-day invitation headings and blank context-only subheadings. No live model or packaged UI review was performed in this slice.

## User-added media as original summary content (2026-11-17)

Explicitly uploaded or recorded media is now primary original content for summaries, including video files and other supported media uploads. Included transcripts remain original recognized speech; extracted descriptions from user-added media can inform the heading and summary while being labeled as potentially incomplete. Automatically connected Photos clues remain lower-priority uncertain context, followed by Calendar and weather. Unprocessed user-added files count as original content but are described only as added files until their contents are extracted. Summary cache fingerprint version 5 invalidates prior summaries under the updated source rules.

Evaluation: `npm run build`, all 14 web tests, and all 28 native tests passed. Tests cover user-added analyzed and unprocessed video, AI inclusion, and distinction from connected Photos clues. No live model or packaged UI review was performed; model-generated phrasing for media descriptions remains unverified.

## Scope

Permanent workspace: /Users/prestonhancock/GitHub/CS301R/Final-Project-3. Created from the staged source after the parent workspace became writable. Dependencies installed and the app rebuilt from this location; neither predecessor is a build dependency. No live predecessor journal was read or changed.

## Implemented

- Standalone pinned React/TypeScript build with local offline npm distributions and lockfile.
- Responsive week/day, inline composer, plain-text search and connection-status UI. Real data is never populated from samples.
- Packaged native WKWebView, message replies with version/request correlation and deadlines, main-frame/local-resource trust checks and navigation restrictions.
- SQLite entry CRUD, occurrence day/timezone, per-entry future AI preference, transactional writes, idempotent creation, revision conflicts and per-day persistent drafts.
- Separate native app identity/data location; arbitrary --vault only through native process launch, never the web bridge.

## Evaluation results

- Offline install of 23 vendored distributions succeeded; TypeScript and Vite production build passed. A separate clean directory with no node_modules and a fresh empty cache also installed and built offline, demonstrating relocation without sibling dependencies. npm ci currently rejects omitted optional-platform entries; use npm install --offline for this Darwin-arm64 bootstrap and resolve standard CI when registry access is available.
- Native service tests: 6 passed covering restarts/drafts, idempotency/revision conflicts, invalid dates/size limits, dispatcher validation, external/subframe/traversal/symlink policy rejection, embedded-null draft preservation, and rejection of newer database versions without downgrading them.
- Mac host compiled, packaged and strict signature verification passed.
- Native UI review in a separate review bundle and synthetic vault: real bridge save, multi-paragraph original display, week count, draft preservation during navigation, quit/reopen persistence all passed. SQLite independently verified afterward. See native-review.json.
- Permanent-location rebuild and fresh isolated native UI save passed. iPhone project scaffolding is included; real iPhone build and live adversarial-frame checks remain open. Phase 0/1 Mac foundation works; full phase 1 is not claimed complete.

## Open gates

- Native host now reports navigation/process failures with a retry screen. Local-document trust policy has unit coverage; adversarial live WebKit frame-injection and process-termination evaluation remain open.
- iOS project, shared scheme and local web-asset preparation script are included. Project/plist/XML and relative paths validated; actual iOS compilation, keyboard/safe-area and device checks require full Xcode.
- Backup/restore and recovery bin are not implemented. Delete has explicit confirmation and is permanent in this slice.
- Browser-only preview is intentionally read-only. Browser-native parity and service adapters remain future phases.
- Weather, model integration and direct Google Calendar OAuth remain open. Photos and system Calendar now have opt-in native connections; see the dedicated media feature record for recording and upload evaluation.
- Optional offline package archives contain the currently installed darwin-arm64 build-tool dependencies; another OS/CPU needs a matching dependency bootstrap.

## Environment

Node v24.20.0; Swift 6.4.2; selected CommandLineTools; macOS26.5 compatibility SDK. Standard registry downloads are restricted. The npm ownership warning when attempting to write ~/.npm was a sandbox write denial, not evidence that global cache ownership needs changing. The successful install uses a temporary writable npm cache. No chmod/chown, DNS or security changes made.

## Permanent workspace follow-up

See permanent-tests.log, permanent-package.log, prepare-ios.log and permanent-native-review.json. Embedded nulls are retained by byte-counted SQLite bind/read; future schema versions fail without mutation. Added native WebKit failure/retry handling and extracted the main-frame/local-document policy for testing. No new source permissions requested. The currently installed Xcode toolchain remains CommandLineTools; iPhone compile was not attempted without an SDK.

## Figma scrapbook UI update (2026-11-12)

- Restyled the React surfaces around the supplied Figma reference: cloth-like green book background, open-book week spread, offset paper scraps with tape and clips, warm paper tones, serif headings and local handwritten annotations. Day reader, search, review and Workshop use the same visual language; narrow screens use staggered cards and a bottom navigation bar.
- Preserved native-backed day loading, inline text save/edit/delete, plain-text search and draft behavior. Week excerpts show saved original text and honor each entry's AI inclusion preference. No sample scrapbook stories are bundled into normal app data.
- Added locally bundled Caveat and Courier Prime fonts with licenses and updated the production package to include font assets. The packaged app remains network-independent.
- Verification: four web tests and six native service tests passed; production Mac bundle built and strict codesign verification passed; iOS web assets prepared. A disposable synthetic Mac UI review verified save and search. The 390-point visual layout was inspected. A final accessibility-tree refresh was blocked when the computer-use host stopped starting, so the added header accessible names are source-verified but the refreshed phone accessibility tree could not be independently observed in this pass. Full iOS build/device behavior remains unverified.
- Logs: figma-web-tests.log, figma-native-tests.log, figma-package.log, figma-ios-assets.log.

## Photos and Calendar connections (2026-11-12)

- Workshop toggles call the native bridge; status checks at launch do not prompt. Turning a connection off prevents future reads by the app but does not revoke the OS permission. System Settings controls revocation.
- Photos uses PhotoKit date matching and returns locally resized thumbnails for the selected day. Limited library access is accepted and labeled. PhotoKit can retrieve iCloud Photos assets when available.
- Calendar uses EventKit full event access and shows title, time, all-day state and location for events on the selected date. It reads calendars configured in Apple Calendar, including Google calendars synchronized with the device. This is not direct Google OAuth/API sync.
- Automated checks: 6 native service tests and 4 web tests passed; TypeScript/Vite and macOS Swift package build passed; both plist/project files lint clean; the Mac app packages and passes strict code-signature verification. Actual permission prompts, iCloud download behavior and iPhone compilation are not verified here.
- Details: photos-calendar.md.
- Follow-up: PhotoKit date matches were present, but thumbnails were blocked by the bundled CSP because `data:` images were not allowed. The policy now allows `data:` only for `img-src`, with a regression test. The Mac bundle was rebuilt; an end-to-end image check still needs the app reopened because the computer-use host could not launch it here.

## Text, audio, video and media uploads

Implementation plan, code and evaluation: `docs/decisions/0004-media-memories.md`. The bridge stores supported attachments in a private vault directory with SQLite metadata, stages chunked uploads, and supports chunk reads for playback. The day UI supports text imports, photo/audio/video uploads, recording full audio, and recording video with sound. Capture permission is requested only from the corresponding Record action. Recording is not transcribed. Text-only, photo-only and recording-only days count in week/review summaries.

Evaluation passed: 8 native service tests (including v1-to-v2 migration, chunk ordering, incomplete/cancelled transfer, restart-stable asset metadata and readback) and 6 web tests. TypeScript/Vite and macOS host builds passed; plist/project lint and strict Mac code signature passed. iOS assets are prepared, but full Xcode compilation and real camera/microphone permission capture remain unverified in this environment.

## Automatic day summaries (2026-11-12)

- Week cards and the open day derive a concise heading/body from current AI-enabled original text; the summary is recomputed from refreshed entry state after create/edit/delete. Original entries remain unchanged.
- Media-only days show a neutral attachment summary. Connected Photos add a count, and Calendar adds up to two events explicitly labeled as plans. Audio/video transcription and visual understanding are not implemented in this workspace yet; no media content is claimed as analyzed.
- Evaluation: 8 web tests passed, including text prioritization, excluded-entry behavior, media-only fallback wording, and source-text preservation. TypeScript and production Vite build passed. See `docs/decisions/0005-automatic-day-summaries.md`.

## Weekly summary (2026-11-12)

- The Week screen evaluates all AI-enabled written entries in the displayed week, ranks them deterministically by detail and specificity, and presents a concise event heading, original explanation, and link to the selected day.
- Evaluation: 9 web tests passed, including strongest-entry selection across different days and exclusion behavior. TypeScript/Vite production build and signed Mac packaging passed. This is an extractive ranking, not a generated LLM synthesis; audio transcription and video understanding remain unavailable.

## Editable daily headings (2026-11-12)

- Every day continues to show an automatically derived heading and explanation by default. The day page now has an editor for custom heading/subheading and a Regenerate automatically action; saved edits persist in SQLite and also appear on the Week card.
- Added schema 3 migration and validated bridge methods for reading, saving and clearing per-day overrides. Existing entries and media are unchanged.
- Evaluation: 9 native service tests and 9 web tests passed; production build and signed Mac package passed. UI interaction was source-checked; no personal journal edits were made during evaluation. See `docs/decisions/0007-editable-day-summaries.md`.

## Persistent Photos and Calendar switches (2026-11-12)

- Connection choices now live in the journal's SQLite settings and survive app restarts. Existing UserDefaults choices are imported once on startup. Startup checks current OS authorization without requesting it; revoked access reports disabled until the user turns the switch on again.
- Schema 4 adds the settings table; native tests cover defaults, persistence, disable state, and invalid resource names. 10 native tests passed and the signed Mac package rebuilt. Physical iOS restart/permission behavior remains unverified.


## Prior-version feature backlog and On this day (2026-11-12)

Compared Final-Project and Final-Project-2 documentation/source against Final-Project-3. Added `docs/FUTURE-FEATURES.md` with missing prior capabilities, ranked so semantic photo/video search retains the user's previously stated top priority. Started the next contained reintroduction: a weekly On this day section built from matching earlier dates in the local day index. It shows at most four cards, summarizes only eligible text, uses neutral counts otherwise, and opens the original day. No new permissions or persistence were added.

Evaluation: TypeScript/Vite production build passed. The first packaging attempt encountered a transient SpeechJobs initializer mismatch while its bridge source was being updated; rerunning after the update passed the Swift host build, package and strict code signature. The UI was not evaluated against personal journal data. Hide/restore controls and synthetic anniversary-state UI review remain open.

## Local semantic memory indexing (2026-11-12)

- Added schema v5 source-revision keyed embedding storage and an Apple NaturalLanguage sentence-vector index. New text entries default to local semantic indexing; entries explicitly excluded from AI remain excluded. Find now ranks results by query-vector cosine similarity and discloses its literal-match fallback when the OS embedding model is unavailable.
- New included audio/video memories automatically enter the existing on-device transcription flow after save. Transcripts are embedded and feed the automatic day summary. Photos and video uploads are analyzed locally with Vision classification/OCR; at most three video frames are sampled. Extracted labels and visible text are embedded for Find and included as qualified summary context. Original media is preserved on analysis failures.
- AI exclusion and deletion clear vectors; text edits replace the prior revision. No remote model/service was added.
- Evaluation: TypeScript/Vite production build passed; JournalServices Swift package build passed; `bash scripts/package-mac.sh` rebuilt the production UI, compiled the Mac host, and signed the development bundle. A direct host build without the project flags hit the selected Command Line Tools SwiftUI macro limitation; the configured package script succeeded. Runtime inference on synthetic media and iPhone build/device behavior were not exercised here.
- Limits: These are text embeddings of writing, speech transcripts and Vision-derived clues. Raw acoustic/image vectors, a shared text-image embedding space, full-frame video analysis and automatic backfill of older media are not implemented. Speech/vision inference quality and runtime remain to be evaluated on devices. See `docs/decisions/0008-local-semantic-memory-index.md`.


## Unified memory composer and spoken summaries

The Add to this day card now contains default typing, Dictate text, Record audio, Record video and file upload. Dictation appends to a durable text draft; full audio/video originals remain playable. Inclusion-enabled recordings can be transcribed locally and contribute to daily/weekly summaries with recognized-text provenance. Saved recordings offer inclusion, retry and cancel. Exclusion clears derived speech text; stale/deleted-source results cannot publish. The current UI inclusion choice overrides the default media inclusion setting for newly saved recordings.

13 native and 12 web checks passed; Mac build/package/signature passed; iOS assets and project/plist lint passed. An isolated native fixture review verified the unified controls and day/week transcript summaries. Actual camera/microphone capture, real Speech inference and physical iPhone validation remain unverified. Details: docs/decisions/0009-unified-memory-composer.md; reports/unified-composer-results.json and unified-composer-*.log. Prior notes saying no transcription describe earlier slices.


## Semantic photo and video search first slice (2026-11-12)

Added explicit search scopes for all memories, photos/videos, and written/audio content. Existing on-device Vision extracts labels/visible text from opted-in day uploads (with sampled frames for video), and NaturalLanguage sentence embeddings rank matching clue text locally. Result cards include an available local preview and open the source day. Excluded assets are filtered by the native index. No media/query content is sent to an AI service.

Evaluation: TypeScript/Vite production build passed; Swift native host compiled, Mac package built and strict signature verification passed. A personal journal UI walkthrough was not performed. This slice searches uploaded day media only; connected PhotoKit library indexing, direct pixel CLIP embeddings, batch progress/cancel, and Google Photos Picker import remain open. See `docs/milestones/Semantic-Photo-Video-Search.md`.

## Compact source-grounded summaries (2026-11-13)

Replaced the day text concatenation / richest weekly excerpt with a native Apple Foundation Models synthesis path. Included text, recognized speech, uploaded-media Vision clues, loaded connected-photo Vision/OCR clues, calendar plans (including time/place) and available selected-city weather form typed evidence. Source text is treated as untrusted data. Every evidence segment is processed through bounded batches, then daily and weekly condensation; failures publish no generated result. Titles/details and source references are validated, long verbatim copies rejected, and jobs support polling/cancellation/deadlines. Source edits/exclusion/deletion invalidate publication and completed-job reads. Manual headings remain authoritative in the UI. A previously unchecked written memory leaking into day detail is fixed. The unavailable path shows a compact, deduplicated, explicitly labeled source preview.

Evaluation: 20 native and 12 web checks passed; production TypeScript/Vite build, signed Mac package and iOS web-asset preparation passed. Real-model synthetic inference was attempted separately: OS reports `.available`, but inference fails with FoundationModels error -1 / ModelManagerServices 1008. Generated prose quality is **not yet validated** on a functioning model, and native job failure falls back honestly. No personal-library permissions were granted. Connected Photos uses at most 12 loaded previews per day, Vision is uncertain, and unprocessed media supplies no event claims; these limits are disclosed. Physical iPhone/full Xcode validation remains open. See docs/decisions/0010-grounded-summaries.md and reports/summaries-results.json / summaries-*.log.

## Find, Review and Add tool drawers (2026-11-13)

Moved Find, Review and Add into sliding drawers while keeping the Week or Day page underneath. The desktop drawer opens beside the left tool rail; compact layouts use a bottom sheet above bottom navigation. Search and review selections open their day and dismiss the drawer. Escape, close button, backdrop, focus containment/restoration, draft persistence and reduced-motion handling are included. The Add drawer reuses the existing text/audio/video composer.

Evaluation: TypeScript/Vite production build passed. `bash scripts/package-mac.sh` rebuilt the UI, compiled the Swift host and signed the development bundle. An isolated visual review used an empty synthetic vault, but Launch Services returned `kLSNoExecutableErr`, and direct executable launch exited 134, so runtime visual behavior could not be inspected. No personal journal data was used. Responsive phone layout is build/source checked only. See `docs/decisions/0010-tool-drawers.md`.

## Apple model-service diagnosis and source-reference fix (2026-11-13)

Follow-up to the summary inference error: a minimal one-word request still fails with ModelManagerServices 1008 in the restricted Swift test harness, while minimal generation **passes in the normally launched native review app** on the same machine. Apple's exact internal reason remains unconfirmed; this experiment isolates the observed failure to the harness execution context rather than establishing a broken system model.

The native probe independently exposed rejected source citations. Added explicit zero-based evidenceIndex fields to model input and citation instructions while retaining grounding validation. Native structured generation then passed. A subsequent mixed-source test through SummaryPipeline passed using synthetic written/speech/visual/calendar/weather evidence. It preserved cancellation, did not follow the injected instruction or claim Denver attendance/location, and passed size/copy/reference checks. It still used a needless “morning report” phrase, so this is concrete successful inference evidence, not comprehensive quality certification.

Added safe domain/code-only diagnostics, more actionable model-service failure text and an isolated native diagnostic view. `bash scripts/prepare-model-diagnostics.sh` prepares a signed diagnostic app without opening a journal or connectors. 22 native + 12 web checks passed; normal production app build/package/signature passed. Restricted live inference remains a separately recorded failing integration gate. No license acceptance, security changes, source permissions or personal-vault access occurred. See docs/decisions/0011-apple-model-diagnostics.md and reports/apple-model-diagnostics-results.json.

## Future-day and calendar-summary grounding (2026-11-16)

Future weekly cards now show only their date, and the app skips loading media, Photos, Calendar, or weather context for those days. Summary requests already stop at today. Summary evidence now follows original writing and recognized speech first, then photo/video clues, with calendar and weather after; calendar input is reduced to a generic uncertain-plan signal, without event titles, times, or locations. Calendar events carry their EventKit timezone to the UI, and event times are formatted in that zone. Calendar day lookup now uses a local Gregorian day interval so daylight-saving days have the correct boundary.

Evaluation: `npm run build` passed. `npm run package` passed, compiling the native bridge and creating/verifying the signed Mac app. SwiftPM emitted warnings because its user-level cache is read-only; these did not prevent the build. No real journal or personal-library permission was used. A live UI/device check of cross-timezone and daylight-saving calendar examples remains open. Details: `docs/milestones/Calendar-Summary-Grounding.md`.

## Multimodal visual understanding (2026-11-17)

User-uploaded photos/videos now have an optional Apple on-device multimodal description path on macOS/iOS 27+ when available. Existing Vision labels/OCR remain the fallback. Video remains bounded to up to three sampled frames. Uploads save originals first, then run cancellable/retryable visual analysis; generated clues feed the existing revision-bound local text embedding index and remain labeled uncertain. Connected Photos previews still use the prior Vision-only path.

Evaluation: TypeScript/Vite production build and JournalServices build against macOS 27.2 SDK passed. Full Mac packaging is blocked because the machine has Command Line Tools but no full Xcode/SwiftUI macro plugin. No image-model inference, synthetic-vault UI review, personal journal, or Photos permission was used. Runtime caption quality, platform/device availability, iPhone build and model cancellation remain unverified. See docs/milestones/Multimodal-Visual-Understanding.md.

## CloudKit cross-device sync planning and setup state (2026-11-17)

Selected opt-in CloudKit private-database sync with per-device SQLite as the local authority. Added a milestone covering eligible and excluded data, conflict/deletion safety, transfer behavior, and acceptance gates. The capability contract and Settings now state that cross-device sync is not active and explain the required Apple Developer registration/container/signing setup. No CloudKit data-transfer engine or sync toggle has been enabled yet.

Evaluation: `npm run build` and `npm run package` passed, including TypeScript checking, Vite production build, Swift host compilation, and development app packaging. SwiftPM reported user-cache write restrictions, but completed. No tests were run. No synthetic vault was needed for this documentation/status-only slice; no personal vault or source permissions were accessed. CloudKit account/container behavior, iPhone build, and two-device sync remain unverified and blocked by the absence of registered bundle IDs, a CloudKit container, and team-signed entitlements. See `docs/milestones/CloudKit-cross-device-sync.md`.

Scope clarification: the first sync release excludes People and Events context records and their day links. AI summary guidance remains in scope to sync. Updated the milestone and Settings description accordingly; no People and Events data is read or changed by this work.

## Active-voice default for summaries (2026-11-17)

Updated the Apple on-device and OpenAI summary instructions to favor direct active verbs (for example, “I visited”) over passive or reporting frames when the evidence directly supports the action. The prompts preserve “I said” when the speaking itself matters, keep user-saved summary guidance, and prohibit converting plans, uncertain visual clues, or other people's actions into completed user actions. Bumped the generated-summary fingerprint version so prior cached summaries are regenerated under the new default.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host compile, Mac development bundle packaging). The first package attempt exposed a Swift compiler error in an existing throwing boolean expression in `ResourceConnections.swift`; split the expression and the subsequent package succeeded, with an existing EventKit deprecation warning and SwiftPM user-cache warnings. No tests or live model inference were run. No journal data or source permissions were accessed; actual prose quality still depends on available model inference. The implementation plan now records active voice as the default summary style.

## No-speech transcription recovery (2026-11-17)

When local Speech returns no words, the error now explains that the recognizer may not understand silent, unclear, or differently-languaged audio, and confirms the original remains saved. Included audio/video attachments with no transcript now have an “Add transcript manually” editor. Saving uses the existing revision-checked transcript update and semantic-index path, so it can contribute to summaries and Find without replacing the original media. Existing transcript edits and automatic retry remain available.

Evaluation: `npm run package` passed (TypeScript, Vite, Swift host compile, and Mac app packaging). No tests or real Speech recognition were run. The build confirms the manual transcript path compiles; it does not establish recognition quality for the affected recording or any language. No personal recording was accessed. See `docs/milestones/Recording-transcription-recovery.md`.

Follow-up UI correction: transcription errors no longer call the page-level failure handler. Both upload-triggered transcription failures and errors from the recording's “Transcribe for summaries and Find” action are shown in that recording's analysis area beside its transcript controls. Successful retry clears the inline error; deleting the attachment clears its error state. `npm run package` passed after this change. No UI automation or user recording was used.

## Weekly page hierarchy and weather strip (2026-11-19)

Reorganized the weekly page into a shared top toolbar, equally tall left/right day pages, a full-width weekly summary as the final section at the bottom, after the optional “On this day” cards, with the week sync/progress row between the spread and those lower sections. The toolbar reads date range, concise weekly weather with a condition icon, week navigation, and Edit from left to right. Day distribution now balances only the two day grids; summary length no longer changes the split. The weather strip summarizes available weather across the displayed dates and omits a temperature range when the week uses multiple locations. Weather is fetched for upcoming dates only for this requested header; future day cards and AI summary context remain unchanged.

Evaluation: `npm run build` and `npm run package` passed (TypeScript/Vite production build, Swift host build, and signed Mac app packaging). SwiftPM emitted read-only cache warnings but completed. No tests or browser UI review were run; the browser access host was unavailable. No personal journal data or source permissions were accessed. The Superdesign draft was inspected but its update could not complete because npm registry access failed with `ENOTFOUND`; the canvas draft therefore remains at its earlier layout.


## Top bar alignment adjustment (2026-11-19)

Removed the weekly weather summary and its icon from the toolbar. Kept the date at left and week navigation/Edit controls at right, centered vertically in the shared bar with balanced padding. Upcoming-day weather lookups used only for the removed toolbar summary have been removed; existing weather context for past days remains available to summaries.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host build, signed Mac app packaging). SwiftPM emitted read-only cache warnings but completed. No tests or browser UI review were run; the browser access host remained unavailable. No personal data or permissions were accessed.


## Remove the app top chrome (2026-11-19)

Removed the fixed brand/action header to give the weekly page more vertical room. The Week, Find, Add, and Review navigation stays on the left rail, and Workshop now opens Settings from that rail. Removed the duplicate top-bar Dates & Review action. Shifted the desktop content and rail upward; compact layouts retain the bottom navigation.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host build, signed Mac app packaging). SwiftPM emitted read-only cache warnings but completed. No tests or browser UI review were run; the browser host was unavailable. No personal data or permissions were accessed.


## Photo-led weekly headline (2026-11-20)

The large image-led day card now retains a visible headline. It uses the generated or saved day title when available, falling back to the local photo-aware day summary, which draws from available photo clues or uses a neutral “day in photos” heading. Increased the headline card’s minimum height and updated spread height estimates so text and extra thumbnails have room.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host build, signed Mac app packaging). No tests or browser UI review were run; the browser host is unavailable. No personal data or source permissions were accessed.
# Compact weekly day cards (2026-11-21)

Weekly day cards now size to their content instead of stretching to fill the page column. Empty days use a shorter date/weather treatment without the generic subheading; lightly populated cards have a lower minimum height, tighter padding and gaps, and generated subheadings are limited to two lines. Photo headlines retain their own large image size. Spread balance estimates for sparse and future days were reduced to match the compact layout. The earlier turn built only the web assets; this pass packages those assets into the desktop app.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host build, signed Mac app packaging). SwiftPM emitted read-only user-cache and deprecation warnings but completed. Browser UI review could not run because the browser access host was unavailable. No personal journal data or source permissions accessed.

## Full-frame larger weekly photos (2026-11-21)

Automatic weekly lead photos now render in normal card flow with `object-fit: contain`, so the complete source frame is visible and the day card grows with the image. Medium and large photo settings have wider limits, and large media has a higher height allowance. Extra-photo tiles also use contain so their thumbnails do not crop the source. Explicit photo placement controls remain in effect. Photo-height estimates used for weekly balancing were increased to match.

Evaluation: `npm run package` passed (TypeScript/Vite build, Swift host build, signed Mac app packaging). SwiftPM emitted read-only user-cache and deprecation warnings but completed. No live visual review; browser access host unavailable. No personal journal data or source permissions accessed.

## Photo-proportioned day cards

The image-led weekly card now spans the available page width and sizes its image to its natural proportions, with date, title, weather and extra images outside the photo. Automatic lead images and extra images use their natural proportions as well. Explicit placement choices remain available. The production web build and signed desktop package passed via `npm run package`; SwiftPM reported cache and deprecation warnings. No synthetic UI review was performed, and no personal data or permissions were accessed.

