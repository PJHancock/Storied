# Plan: text, recording, and uploaded media — 2026-11-12

## Goal

Let a person add a day memory as written text, a direct audio recording, a direct video recording, or a selected text/photo/audio/video file. Imported/recorded assets must persist in the new app's local journal and appear again when reopening that day. Audio is saved as original audio; there is no speech-to-text or model processing in this slice.

## Plan before implementation

1. Extend the native journal schema with an attachment table and a versioned migration from schema v1. Keep binary files under a private media directory inside the journal vault; only generated UUID filenames become paths.
2. Add a bounded, sequential chunk upload protocol to the native bridge. Validate day, UUID, media type, filename and size. Write to a staging file, require the expected byte count, then atomically move the completed file and insert its SQLite metadata. Add chunked reads for audio/video playback and bounded thumbnail reads for photos.
3. Replace the plain composer-only affordance with text, Upload, Record audio, and Record video actions. `.txt` and `.md` uploads populate the editable text draft. Image/audio/video uploads stream into native storage. Use MediaRecorder with runtime format negotiation, stop microphone/camera tracks on all completion/error paths, and ask for capture permission only after the person presses Record.
4. Add day attachment cards with image display and native-file audio/video playback, plus delete confirmation. Include attachment-only days in week/review counts. Keep the browser preview read-only.
5. Evaluate using generated synthetic `.txt`, `.jpg`, `.wav`/`.m4a`, and short `.mp4` fixtures. Cover migration, chunk order/size, incomplete/cancelled uploads, restart persistence, playback bytes, and delete cleanup. Inspect native permission flows only without accepting access to the user's own media.

## Implementation and evaluation record

This file records the plan before implementation. Completion, exact checks, platform limits and any blockers are appended below after implementation.

## Scope boundaries

- Local-only media storage; no server upload, model, transcription or embedding.
- Captures request camera/microphone permission only when recording starts. Selecting files uses the system picker and does not need broad Photo Library permission.
- Initial limits and supported types will be explicit in code and UI. Direct file URLs or arbitrary paths never cross the WebKit bridge.

## Implemented and evaluated

- Added SQLite schema v2 migration and `media_assets` metadata. Attachment bytes live under the app's private journal vault with generated UUID paths and 0600 file mode; upload staging is cleaned on launch. An attachment is published to the database only after all bytes arrive and the file move succeeds.
- Native chunk protocol enforces sequential 256 KiB chunks, UUIDs, validated MIME families, JPEG previews, valid days, and an 80 MiB per-file cap. Readback is chunked too. Delete requires the UI confirmation and removes the asset from the database/vault.
- Day composer now supports `.txt`/`.md` to the editable draft, photo/audio/video file imports, direct full-audio recording, and video recording with sound through MediaRecorder. A runtime MIME negotiation covers supported WebKit formats. Capture asks for microphone/camera permission only after the corresponding Record action; WKUIDelegate grants capture only to the trusted main local document, while OS privacy prompts remain in force. All capture tracks stop after save/discard/error/unmount.
- Photo previews are locally reduced JPEGs; audio/video loads into an on-device Blob only when requested for playback. No model, transcription, external network request, or upload service is involved. Attachment-only days participate in the week/review counts.
- Evaluation: 8 Swift service tests pass, including a simulated v1 database migration, out-of-order and incomplete chunks, cancel cleanup, persistence and byte-perfect chunk readback. 6 web tests pass for date behavior, design content, CSP and media MIME mapping. TypeScript/Vite, macOS Swift host, package/signature, Info plist and Xcode project syntax checks pass; iOS web assets are prepared.

## Remaining platform check

The local Mac package is ready to open. This machine lacks full Xcode, so the iPhone target hasn't been compiled. The computer-use host did not start for a live camera/microphone capture run, and no personal recordings were used. Test the capture prompts and playback on a Mac/iPhone after opening the package/build with full platform access; the UI offers file upload if capture is unavailable. The current player loads each chosen file into memory, so the 80 MiB per-file upper bound may be too high for some phones; reduce the file size if playback runs out of memory.
