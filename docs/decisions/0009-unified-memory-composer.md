# Unified memory composer and spoken memory summaries

## Plan
Keep the default text editor inside one Add to this day card. Place Dictate text, Record audio, Record video and Upload controls in that same card. Dictation becomes a saved text draft; recordings retain original bytes and can be transcribed for daily/weekly summaries when inclusion is enabled. The inclusion control applies to typed text and new recordings. Saved recordings get inclusion, transcription, retry and cancel controls.

Use native on-device Speech with explicit action-time authorization. Audio/video processing runs as a bounded cancellable job, extracting 30-second audio segments from saved originals. Transcripts are derived metadata linked to an unchanged attachment and cleared on exclusion. Existing recordings start excluded unless explicitly opted in. Do not imply that spoken transcript processing understands video scenes or other sounds. No model upload or background microphone collection.

Evaluate schema compatibility, eligibility/revision/delete guards, transcript summaries, dictation append limits, unified component structure, builds, packaging and native UI where available. Actual camera/microphone/Speech inference needs device validation; tests must not request personal permissions.

## Implemented
One composer contains the default text editor and Dictate text, Record audio, Record video, Upload tools. Dictation captures a short input, transcribes it locally, persists appended text as a draft, then removes the temporary captured asset after successful draft save. If recognition/save fails, the audio remains recoverable as a saved recording. Audio/video originals always remain saved. The parent inclusion choice is applied explicitly to each new audio/video file.

Native processing uses bounded on-device Speech requests over 30-second audio segments, including extraction of a video's audio track. Jobs return immediately and can be polled/cancelled. Temporary copies preserve the original bytes and use a codec-appropriate suffix; directories are private. Metadata carries an original content digest and analysis revision. Publication rejects exclusion, deletion and stale source changes. Existing summary helpers accept eligible recognized text with a recognition-accuracy qualifier. Semantic-index integration from the parallel work is retained; an indexing failure cannot invalidate successful transcription.

## Evaluation
13 native checks and 12 web checks passed; TypeScript/Vite and signed Mac package passed; iOS web assets prepared and plist/project lint clean. Native isolated UI/AX review verified one composer and its controls, saved-recording actions and fixture transcript participation in day/week summaries. The fixture transcript was injected synthetic data, not live Speech inference. No real capture/Speech permissions requested. Camera/microphone recording, real local recognition quality, and full iPhone validation remain device checks. The native automation host took over ten minutes to launch the review app; no such app performance conclusion is drawn from that tool delay.

Parallel weather, semantic-index and visual-analysis changes were preserved. Test expectations now allow the explicit weather endpoint CSP and avoid assuming that the overall AI capability remains false once local indexing is available.
