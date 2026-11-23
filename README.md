# Storied

A fresh React scrapbook interface in a native Swift WKWebView app. The visual style follows the supplied Figma reference with an open-book week, paper scraps and warm handwritten details. The app saves text memories and local photo, audio and video attachments; audio/video recording and file uploads are available on supported native WebViews. Opt-in Photos and system Calendar access show day-matched photos and events. OpenAI summaries are optional and use a user-supplied API key; the key is stored in Keychain. AI-enabled journal evidence is sent only after OpenAI summaries are explicitly enabled. Weather, direct Google Calendar OAuth, backup and cross-device sync remain incomplete. Use synthetic notes during evaluation.

## Build and run on Mac

Node 24 and a compatible Swift toolchain are required. The 23 pinned npm distributions under vendor/npm support an offline bootstrap; their licenses are retained inside each archive and installed package. No sibling project is needed to build or run this project. The offline snapshot targets Apple silicon macOS. Use the install command below: npm ci currently rejects missing lock entries for unbundled optional binaries on other platforms; this is an open dependency-bootstrap cleanup before standard CI.

```sh
npm install --offline --ignore-scripts --cache /private/tmp/memory-catcher-3-npm
npm run package
```

Open `.build/Memory Catcher 3.app`. It bundles the React assets and runs without Vite or internet. Normal native data is stored under `~/Library/Application Support/MemoryCatcher3`; this is a new journal, separate from both predecessors.

In Workshop, turn on Photos or Calendar to request OS permission. Photos are read from the system library (including iCloud Photos when available) and reduced to local thumbnails. Calendar reads events available to Apple Calendar, including Google calendars already synced to the device; direct Google account OAuth is still a planned step.

In Workshop, add an OpenAI API key to verify and store it in the native Keychain. Then separately enable OpenAI summaries to permit included journal evidence to be sent when summaries are generated. This uses OpenAI API billing, which may be separate from a ChatGPT subscription. OpenAI receives eligible written memories, included transcripts, local visual clues and selected day context; original media files are not uploaded.

On a day page, write text and save it, upload `.txt`/`.md` into the draft, or upload photos/audio/video (80 MB maximum each). **Record audio** keeps the original audio; **Record video** captures video with sound. Capture permissions are requested only after the respective Record action. Original media stays inside this device's journal vault and is not uploaded for OpenAI summaries. Included audio/video can be transcribed on device when available. OpenAI receives only summary evidence text and selected day context when its summary setting is enabled.

For isolated review use the executable with a disposable folder:

```sh
".build/Memory Catcher 3.app/Contents/MacOS/MemoryCatcherHost" --vault /private/tmp/memory-catcher-3-review
```

To view the browser-only interface:

```sh
npm run dev
```

The browser preview cannot save native memories and does not silently create a separate production browser journal. Native access is registered only by the packaged host. The macOS package has a new identifier `org.example.MemoryCatcher3.Development` and is signed ad hoc for local development.

## Checks

```sh
npm run build
npm test
```

The Swift test runner uses the installed Testing framework. Scripts select the installed 26.5 SDK when present to avoid the Command Line Tools 27 SwiftUI macro mismatch; they do not change system developer settings. See reports/STATUS.md for actual results and open gates.

## iPhone

The iOS target and shared scheme are at `apps/apple/MemoryCatcher.xcodeproj`. Prepare its bundled frontend first:

```sh
bash scripts/prepare-ios.sh
```

Open the project in full Xcode, select MemoryCatcher3, choose a simulator or your signing team/device, and build. The selected toolchain on this machine is CommandLineTools, so actual iOS compilation and device behavior remain unverified. The Mac build does not establish iPhone support.

## Next

Follow IMPLEMENTATION-PLAN.md. Finish bridge trust/lifecycle checks and iPhone packaging, then add managed media and original playback before enabling Photos, Calendar, weather or models. Export/import and a recovery bin must precede real-data cutover.
