# Multimodal visual understanding

Status: implemented; service/web builds pass; native app packaging is blocked by missing full Xcode

## Goal

Improve search and day-summary clues for user-uploaded photos and videos by letting Apple's on-device Foundation Model inspect still images directly. Keep Vision classification/OCR as complementary evidence and as a runtime fallback. Treat all generated descriptions as uncertain clues, never as verified facts.

## Implementation slices

1. Add a native asynchronous, cancellable visual-analysis job for uploaded photos/videos. Saving originals remains immediate; analysis runs separately, reports progress, can be cancelled, and can be retried for existing media.
2. On macOS/iOS 27 and later, if the on-device Foundation Model is available, attach a photo or up to three sampled video frames to one multimodal prompt. Ask for concise, concrete, uncertainty-aware descriptions and prohibit identity, relationship, exact-place, intent, and unsupported motion claims. If unavailable or inference fails, preserve current Vision classification/OCR analysis.
3. Save the generated description alongside bounded Vision clues, then index the text using the existing local sentence-embedding path. Keep source revision/exclusion invalidation intact. Do not add network calls, a downloaded model, or another embedding space.
4. Evaluate with TypeScript/Vite build and signed Mac package. Runtime inference and device quality require a synthetic vault and a supported Apple Intelligence device; record evidence separately from compile success.

## Acceptance checks

- Media uploads finish and originals remain accessible even when visual analysis is unavailable or cancelled.
- The UI exposes analysis progress, cancellation and retry/re-analysis without requiring Photos access.
- Supported OS/device runs an on-device image-capable model; older OS or unavailable model falls back to Vision labels/OCR.
- Video is represented as a small set of still frames, and descriptions do not claim continuous footage understanding or unobserved motion.
- New visual descriptions are labeled as model-generated/uncertain in the UI and feed local Find and summary evidence only when the asset is included.
- The web and JournalServices builds succeed; full native app packaging requires the SwiftUI macro plugin supplied by full Xcode.
- No personal journal or real photo library is used for evaluation.

## Platform evidence

Apple's current Foundation Models documentation and WWDC26 image-understanding session show image attachments in multimodal prompts beginning with iOS 27/macOS 27. There is no built-in video input in the framework; the model can inspect attached sampled frames. This workspace currently has Swift 6.4.2 and macOS 27.2 Command Line Tools, but no full Xcode installation. Physical iPhone validation is unavailable in this environment.

## Implementation and evaluation (2026-11-17)

Added direct multimodal image prompts to the local analyzer for macOS/iOS 27+ when SystemLanguageModel is available. Uploaded images are scaled to at most 1024 pixels on the long edge for the model; video is represented by up to three 640-pixel sampled frames. Captions are constrained to visible, uncertain details and explicitly labeled as model-generated. Existing Vision classification/OCR is retained and runs as fallback. Generated descriptions share the existing local sentence-embedding index and remain revision-bound to the source asset.

Added asynchronous visual-analysis jobs with status, cancel and retry/re-analysis UI. Upload completion now saves the original immediately and analysis runs after; AI exclusion cancels work and removes derived clues. The model is not used for connected Photos-library previews, which continue to use the existing bounded Vision path.

Evaluation: TypeScript/Vite production build passed. The JournalServices package build against the macOS 27.2 SDK passed, compiling the multimodal Foundation Models attachment code and job coordinator. The full Mac package could not compile the SwiftUI host because this machine selects Command Line Tools and has no full Xcode/SwiftUI macro plugin; the installed OS 27 SDK is present. No generated model inference or UI review was run. Runtime caption quality, real-device model availability, cancellation timing, and iPhone behavior are still open. No personal journal or photo-library permission was used.
