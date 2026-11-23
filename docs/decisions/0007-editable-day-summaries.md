# Decision 0007 — Editable day summaries

Date: 2026-11-12. Status: implemented and evaluated.

## Plan

Keep generated heading and explanation as the default for every day. Add a day-level editor that lets the user save a custom heading and subheading, plus a Regenerate action that removes the custom version and immediately returns to the current automatic summary. Persist only explicit user edits in SQLite through the native bridge; leave original memories and the automatic summary derivation untouched.

## Evaluation

Test SQLite persistence, input limits, bridge validation, and UI default/edit/save/regenerate flows. Existing journals migrate additively. Rebuild and package the Mac app after checks.
