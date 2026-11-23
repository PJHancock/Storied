# Decision 0006 — Weekly summary

Date: 2026-11-12. Status: extractive weekly highlight implemented.

## Plan

Use all AI-enabled written memories from the visible week as candidates. Rank entries deterministically by detail and specificity, then show the strongest event as a concise heading with its original explanation and date. Preserve the source text. If no eligible narrative exists, show an empty-week state. A model-generated synthesis remains unavailable until an AI provider is implemented and evaluated.

## Evaluation

Web tests verify that ranking considers entries across the week, favors a detailed event over a short generic note, and leaves source text intact. Production build and Mac packaging are the release checks for this slice.
