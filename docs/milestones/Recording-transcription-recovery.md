# Recording transcription recovery

Status: improved recovery path implemented; live speech recognition quality remains device/content dependent.

## Problem and plan

When on-device Speech returns no words across all audio segments, `SpeechJobs` fails with a no-speech error. The original attachment remains saved. This is a valid outcome for silence or speech the selected recognizer cannot understand, but the day page did not offer a way to add a transcript when automatic recognition returned nothing.

Add a manual transcript path for included audio/video originals. Keep automatic transcription and the original bytes unchanged. Clearly explain that playback loading is separate from transcription and summary inclusion. A manual transcript should use the existing revision, AI-inclusion and local-index update paths.

## Acceptance

- Empty/no-speech output retains the original and explains that speech may be absent, unclear, or in a different language.
- Transcription failures appear beside the affected recording's transcription controls, not in the page-level error banner; this covers both automatic and user-triggered transcription.
- Included audio/video memories offer “Add transcript manually” when no transcript exists.
- Saving manual transcript text persists it, indexes it locally, and allows it to contribute to summaries; excluded media cannot save a transcript.
- Existing transcript edits, automatic transcription, stale-revision checks, and original media bytes remain intact.
- Build evidence is recorded. Actual Speech recognition still needs a synthetic spoken recording/device evaluation; never use a user's personal recording as a test fixture.
