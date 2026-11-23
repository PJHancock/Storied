# Semantic photo and video search

## Plan

Use the existing on-device media pipeline: Vision derives bounded labels and visible text from user-added photo/video files (and sampled video frames), then NaturalLanguage sentence embeddings index those clues under the media asset revision. Search stays on device and only includes media the user opted into processing. Keep the original media authoritative; embedding/search output is derived and revision-bound.

## First implementation slice

- Add an explicit Photos & videos scope to Find, alongside all memories and written/audio memories.
- Return photo/video semantic matches with a small local preview when one exists and a direct link to the day containing the original.
- Clearly explain how to make a photo/video searchable: add it to a day and enable its per-asset visual clues setting.
- Keep unsupported/unavailable embeddings honest and retain literal fallback behavior.
- Do not send image, video, extracted text, or query content to a hosted model.

## Boundaries

This slice covers uploaded media in the app vault. Indexing every item in the connected Apple Photos library, Google Photos Picker import, background rescans, persistent progress/cancellation, and a joint image/text CLIP vector model are follow-up work; the current app has no model asset bundle for CLIP. Text clues from Vision are semantically ranked locally, but this is not direct pixel-vector search and may miss visual details.

## Evaluation

TypeScript production build and Mac package build are the first gates. Manual UI review should use a disposable synthetic vault with one opted-in photo, one opted-in video and one excluded asset; verify matching scope, preview and day link without reading the personal vault.


## Implementation and evaluation (2026-11-12)

Find now exposes All memories, Photos & videos, and Words & audio scopes. The typed bridge passes scope to the native query; native search filters by scope before result limiting and ranks eligible media clues locally. Matching media results display a local thumbnail where available and open the source day. Build and package passed: TypeScript/Vite, Swift host, and strict Mac signature. No fixture-based UI run was performed. Connected PhotoKit library assets and direct CLIP vectors are not included in this first slice.
