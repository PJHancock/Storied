# OpenAI API key and summaries

Date: 2026-11-17

## Decision

Add OpenAI as an explicitly enabled summary provider. The user enters their own OpenAI API key in Workshop, verifies it against the OpenAI Models endpoint, and the native service stores it in the device Keychain. The React interface never reads the saved value. Removing the key also disables the provider.

OpenAI uses the Responses API with the `gpt-6-luna` model and strict JSON Schema output for grounded day and week summaries. The existing native evidence selection and validation remain authoritative: only entries and media-derived text marked for AI plus the selected summary context are sent. Original image, audio, and video bytes are not sent. A disabled OpenAI setting routes to the existing Apple provider. An enabled setting does not silently fall back to Apple if OpenAI fails; the UI reports the error and retains the existing source preview.

The setting is off by default and separate from saving the API key. Enabling it authorizes automatic summary requests as the user loads or refreshes a week. Workshop explains the evidence sent, the network requirement and possible API charges. Disabling it stops later requests. The app does not claim that a ChatGPT subscription automatically pays for API usage.

## Security and data handling

- The key is sent only from the trusted bundled main frame to the native bridge when the user taps Verify & save. The native code verifies it, stores it in Keychain with `WhenUnlockedThisDeviceOnly` on iOS, and never returns it.
- Key verification calls `GET https://api.openai.com/v1/models`; no journal evidence is included in that request.
- Summary requests use `POST https://api.openai.com/v1/responses` with `store: false`, bearer authentication, and a bounded JSON evidence payload.
- Provider calls use an ephemeral URL session. Error messages do not include authorization headers, prompts, evidence, or raw provider responses.
- API keys are per user's own OpenAI developer account. No app-owned API credential or backend is introduced.

## Scope and limits

This slice uses OpenAI only for generated day/week summaries. It does not replace local semantic search, transcription or Vision analysis. Verification confirms key and model-list access; it does not prove billing is active or guarantee a future summary succeeds. A physical iPhone build and live API exercise remain required. The current environment has Command Line Tools without an iPhone SDK, and no API key or personal journal was used for evaluation.

## Evaluation record

The web production build and iOS asset preparation passed. The JournalServices package compiled, including the OpenAI provider and Keychain code. Full Mac app packaging did not pass: the selected Command Line Tools 27.2 cannot load its SwiftUI macro plugin; a full build with the installed macOS 26.5 SDK fails in existing `OnDeviceVisualAnalyzer.swift` because that SDK lacks its Foundation Models `Attachment` symbol. Automated tests and live OpenAI calls were not run. No API key or journal data was used.
