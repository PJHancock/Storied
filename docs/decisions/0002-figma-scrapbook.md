# Figma scrapbook reference implementation

Reference: https://www.figma.com/make/nr0IvuFKIgevQP8VNhHNbN/Outline-App-Features

Observed live Figma Make version 3 through native Chrome on 2026-11-12: woven dark green cloth, aged open-book spread and brass spine, mature serif headings, handwritten personal annotations, loose clay/sage/linen paper scraps, uneven tape, varied day-card sizes, quiet empty/future placeholders, week filling progressively. Also inspected the day reader. Local version-1 export under Final-Project/Outline App Features supplies the user's SVG icon primitives; it is not treated as the latest visual baseline.

Implement this visual direction on the existing Final-Project-3 native bridge. Use only real journal data; no hard-coded Figma sample stories, weather, people or photographs in the normal app. Preserve paragraphs, drafts, edit/delete, date selection, storage, consent and unavailable capability messages. Future dates are disabled and unfilled past days remain available. Explicitly separate a weekly excerpt from AI-generated synthesis.

Superdesign workflow context initialized locally. Its CLI is unavailable in the offline package cache; no source/journal data was uploaded and no remote draft generated. Implement directly from the supplied reference and locally available user-owned source primitives. Local assets only in the production app.

Evaluation: TypeScript/Vite build, packaged native app, model/date tests, existing six native regressions, isolated populated-week/day UI review; check narrow layouts, large text and reduced motion where possible. iOS device validation remains separate.
