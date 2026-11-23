# Decision 0008 — Local semantic memory index

Date: 2026-11-12. Status: plan and initial implementation.

## Goal

Index eligible new text and extracted media content locally as memories are added. Use the same index to rank Find results by meaning and to provide analyzed memory content to daily summaries. Preserve originals and allow source revisions or AI exclusion to invalidate derived artifacts.

## Plan

1. Keep an explicit local processing opt-in on each memory. New memories default to included because automatic indexing is the requested behavior; existing exclusions remain exclusions. No network model or API is introduced.
2. Store embeddings as versioned, source-keyed artifacts in SQLite, including the source revision/digest and analyzer identifier. A source update replaces its artifact; delete/exclusion removes it. Keep original text/media authoritative.
3. Use Apple's on-device NaturalLanguage sentence embedding when available for text and transcripts. Search embeds the query locally, ranks vectors by cosine similarity, and includes literal-match fallback when the OS embedding is unavailable.
4. Media adapters must produce a real on-device representation before marking an asset indexed: Speech transcript embeddings for audio/video speech; Vision feature prints and recognized text/labels for image and sampled video frames. Keep modality-specific vectors distinct; do not claim Vision feature prints share a text-query space. Text derived from recognized labels/OCR/transcripts may join the text search and summary context.
5. Rebuild day summaries from eligible indexed text/transcripts/recognized visual descriptions plus existing deterministic metadata. Keep user-edited headings intact until a source changes, as today.
6. Bound work and persist progress/failure states. Do not request permissions on app launch. Never upload originals or silently call a remote provider.

## Evaluation plan

Use synthetic text and media fixtures only. Check save/update/delete/exclusion invalidation, restart persistence, semantic ranking for paraphrases, and transparent fallback when an Apple model or permission is unavailable. Validate real Vision/Speech model availability only on supported Apple hardware; package compilation alone is not evidence of inference quality.

## Implementation note

The workspace has no shared text-image embedding model. Photos and video are represented in the text space through on-device Vision labels and OCR from the photo or a few sampled video frames. Raw Vision feature prints are not comparable to text vectors, and raw acoustic vectors are not available in this slice.

## Implemented

- Schema v5 adds a durable local embedding table keyed by source ID, type, revision and model name. Source edits, deletion and AI exclusion invalidate artifacts.
- New text memories default to local indexing. Apple NaturalLanguage sentence vectors are created at save time when the English sentence model is available. Find embeds the query and ranks current eligible text and media artifacts with cosine similarity; older eligible text is backfilled on first query. If the model is unavailable, the UI discloses a literal-match fallback.
- New included audio/video recordings use the existing on-device Speech flow after upload/capture; the recognized transcript is embedded and contributes to the day summary. Speech authorization remains action-triggered by adding or explicitly processing a recording.
- New photo/video uploads run bounded on-device Vision classification and OCR. Photos analyze one image; videos sample at most three frames. The resulting labels and visible text are sentence-embedded and can inform Find and day summaries. The UI labels these as incomplete visual clues.
- The native app remains local-only; no provider/model download or server endpoint was added.

## Evaluation update

- `npm run build` (TypeScript and Vite production bundle): passed after the semantic Find and media-summary UI changes.
- `swift build` in `packages/JournalServices`: passed, including NaturalLanguage, Vision and AVFoundation adapters. Existing AVFoundation concurrency and toolchain framework-path warnings remain; video duration has a deprecation warning on this SDK.
- `bash scripts/package-mac.sh`: passed; production interface rebuilt, Mac host compiled and development package signed. A direct `swift build --package-path apps/apple` invocation without the repository toolchain flags failed because the selected Command Line Tools lack the SwiftUI macro plugin; the project packaging script uses its configured SDK flags and succeeded.
- No iPhone SDK/device or live synthetic media inference was available in this environment, so runtime model quality and performance remain unverified.

## Limits

This is text-space semantic indexing of text, transcripts, Vision labels and OCR. It does not produce a shared CLIP-like visual/text vector, raw acoustic embeddings, or continuous per-frame video understanding. Vision may return no useful labels/OCR, and Speech may be unavailable or denied; in those cases the original remains saved and its derived artifact is absent. Existing media is not automatically backfilled yet. The daily summary consumes the eligible transcript/visual clue text; embeddings currently drive Find ranking rather than generated summary wording.
