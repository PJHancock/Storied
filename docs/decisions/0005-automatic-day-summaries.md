# Decision 0005 — Automatic day summaries

Date: 2026-11-12. Status: first extractive UI slice implemented.

## Plan

Rebuild a concise day-card summary whenever the currently loaded day entries or connected context change. Use user text as the primary source and preserve the user's wording; derive a short event-focused heading from its opening sentence and show the fuller text underneath. This deterministic local excerpt remains available when AI processing is excluded. Add photo counts and clearly labeled calendar plans as supporting context. If no text exists, describe saved attachments without claiming to have analyzed them. Do not imply audio/video transcription or visual understanding until those processing paths exist in this workspace. Keep originals authoritative and use existing refresh flows rather than introducing a separate summary database.

## Evaluation

The web tests cover summary prioritization, media-only fallback copy, and source-text preservation. Native recording transcription, visual understanding, and model-generated summaries remain future work. Photo counts and calendar plans are included as qualified metadata.
