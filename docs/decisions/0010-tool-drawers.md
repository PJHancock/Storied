# Decision 0010 — Find, Review, and Add tool drawers

Date: 2026-11-13. Status: implemented; production web build and signed Mac package passed.

## Plan

- Keep the current Week or Day as the underlying page. Move Find, Review, and Add content into one mutually exclusive drawer controlled independently from the page route.
- Attach the desktop paper drawer to the fixed left tool rail, with a dim desk scrim over the book. At phone widths, use a bottom sheet above the bottom navigation.
- Preserve the existing Find scope/results, Review date and day list, and Add text/media composer. Selecting a result/date opens that day and closes the drawer.
- Support close button, backdrop click, Escape, focus containment/restoration, reduced motion, and draft persistence.

## Implemented

- Added `drawer` state separate from `page`; the week/day stays rendered underneath and becomes inert while the dialog is open.
- Find and Review open from the rail; Review also opens from the header. Add opens the existing text/audio/video composer in the drawer. The day page's inline composer hides while the Add drawer is open to avoid mounting a second recorder.
- The desktop drawer slides out beside the fixed rail. On compact screens it becomes a bottom sheet above bottom navigation. Scrim click, close button, and Escape dismiss it. Focus moves into the drawer, stays inside while open, and returns to the triggering button.
- A search result or selected day closes the drawer and navigates to the chosen day. Opening and closing persists the current text draft as before.

## Evaluation

- TypeScript/Vite production build passed.
- `bash scripts/package-mac.sh` rebuilt the UI, compiled the Swift host and signed the development bundle.
- An isolated visual review was attempted with an empty synthetic vault. Launch Services returned `kLSNoExecutableErr` when opening the packaged app, and direct launch of the bundled executable exited with code 134. The UI therefore could not be visually inspected in this pass; no personal journal data was used.
- iPhone compilation/device behavior is outside this pass; the responsive layout is source/build checked only.
