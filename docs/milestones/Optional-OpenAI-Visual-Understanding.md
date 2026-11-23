# Optional OpenAI visual understanding

Status: implemented; build and packaging gates pass; live provider inference not evaluated

## Goal

Let the existing user-provided OpenAI API key power uploaded-photo/video descriptions as an explicit, independent option alongside OpenAI summaries. Keep local Apple Intelligence and Vision as the default when the visual option is off.

## Plan

1. Add a visual-provider preference to the existing Keychain-backed OpenAI connection. Keep summary and visual preferences independent; removing the key disables both.
2. Add an OpenAI Responses image-input provider using the existing GPT-6 Luna model. Downsize uploaded images and video frames before encoding. Use the same concise, uncertainty-aware grounding policy as the local visual analyzer.
3. Route each visual job to OpenAI only when the user enabled visual understanding and the key exists. Otherwise keep the on-device Apple/Vision path. Never send connected Photos-library images through this provider.
4. Update Settings to explain that uploaded photos or sampled video frames are sent to OpenAI only when this option is enabled; show the model, billing caveat, and independent summary setting.
5. Evaluate TypeScript/Vite and JournalServices builds. Do not use a personal key, send real media, access a personal journal, or grant library permission. Record package/device limitations.

## Acceptance checks

- OpenAI summaries can be enabled without OpenAI visual analysis, and vice versa.
- The API key remains in Keychain and is never exposed to React or logs.
- With visual opt-in off, no OpenAI image request is made and existing Apple/Vision behavior remains.
- With visual opt-in on, only uploaded photo bytes or at most three sampled video frames are sent to the Responses API; original audio/video files and connected Photos-library media are not sent.
- The result remains labeled as uncertain and feeds the existing local embedding index. API failure leaves the original intact and reports the failure.
- Web and JournalServices builds pass; no real user data or API key is used in evaluation.

## API evidence

The existing configured model is GPT-6 Luna. OpenAI's official model reference lists image input for this model, and the official Images and Vision guide documents base64 data URLs in Responses API input. See https://developers.openai.com/api/docs/models/gpt-6-luna and https://developers.openai.com/api/docs/guides/images-vision.

## Implementation and evaluation (2026-11-17)

- Added a separate OpenAI visual-understanding preference beside the existing independent OpenAI summary preference. Both use the API key held in native Keychain; removing the key turns both options off. The key is never returned to React.
- Uploaded photo and video analysis uses GPT-6 Luna only when visual understanding is explicitly enabled. The provider sends JPEGs resized to at most 1024 pixels on the long edge: the uploaded photo or up to three sampled video frames. The original audio/video file is not uploaded, and connected Photos-library images remain on the local Vision-only path.
- OpenAI descriptions are labeled as uncertain, combined with local Vision labels/OCR, and indexed using the existing on-device semantic index. If the OpenAI request fails, local Vision clues are kept when available and the job reports the provider failure.
- Settings and media composer explain the separate controls and data flow. React remains a presentation layer; the native service owns the key, preference, image preparation, and network request.
- Evaluated with `npm run build`, `swift build --package-path packages/JournalServices --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX27.2.sdk`, and `npm run package`. All passed, including the signed Mac bundle build. Existing deprecation and AVFoundation Sendable warnings remain.
- No tests were added or run, per the workspace task instructions. No API key, real photo/video, personal journal, or Photos-library permission was used, so live OpenAI inference, actual billing, and visual output quality remain unverified. No iPhone/device build or UI runtime review was performed.

The other current Apple/local language-related capabilities are on-device speech recognition and NaturalLanguage embeddings. They are not Apple Intelligence model calls in this implementation, so this slice leaves them local and unchanged.
