# Future days and calendar summary grounding

Status: implemented; build/package evaluated

## Slice plan

1. Keep future days empty in the weekly scrapbook and exclude them from summary generation.
2. Preserve original memories as the primary evidence. Give uploaded audio/video transcripts and visual clues priority over connected-photo clues, then calendar plans. Keep calendar evidence clearly labeled as uncertain plans and omit raw time/location metadata from generated summary context.
3. Correct calendar event display timing by carrying each EventKit event's timezone across the native bridge and formatting the event's instant in that timezone. Build the queried day interval from local Gregorian components and the local calendar day interval, including daylight-saving transitions.
4. Evaluate with the production UI build and configured Mac package build. Record unavailable runtime/device evidence; do not grant personal-library access or use a real journal for evaluation.

## Acceptance checks

- Future weekly cells show only their date and do not display a summary, memory count, photo, or generated copy.
- Summary requests contain only dates up through today.
- Source preview order is original writing and recognized speech, then user-uploaded/connected-photo evidence, then calendar plans; weather remains contextual. Calendar evidence does not establish attendance and event titles are not included unless independently corroborated by a memory.
- Calendar event clock times render in the event timezone; all-day events remain labeled all day. Day querying uses the local journal day boundary.
- TypeScript/Vite production build and Mac packaging complete successfully.

## Evaluation

`npm run build` passed after the changes. `npm run package` passed, including compilation of `ResourceConnections.swift` and strict development signing of `.build/Memory Catcher 3.app`. SwiftPM emitted pre-existing environment warnings because its user cache is read-only; build and signing still completed. No personal-library permission or real-journal evaluation was used. A live UI/device check of daylight-saving and cross-timezone calendar examples remains unverified.
