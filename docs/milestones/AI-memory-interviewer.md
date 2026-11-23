# AI memory interviewer

Status: planned; not implemented

## Goal

Offer an optional, short interview that helps the user add concrete details to a selected photo or calendar event while keeping the journal owner's recollections distinct from generated prompts and source metadata.

## Planned experience

1. The user explicitly chooses “Help me remember” from a photo or calendar event. The interviewer uses only that selected item and its already available, eligible details.
2. Ask one open-ended question at a time. Examples include “What was happening just before this photo?” and “What do you remember about this event?” Follow-up questions should clarify the user's answer rather than assume details that are not present.
3. For visual inputs, use visible content only as an uncertain cue. Do not infer identity, relationships, exact location, intent, emotion, or unseen events. Phrase uncertain cues as questions, not claims.
4. Calendar entries are plans, not proof that an event happened. Ask whether the user attended or took part before asking what they remember; never write attendance as fact based on the calendar alone.
5. The user can skip questions, stop at any time, edit answers, and review the assembled recollection. Nothing is added to the journal until the user explicitly saves it. Keep the original photo, event record and existing memories unchanged; link the saved recollection to its selected source where possible.

## Privacy and architecture

- Keep React as presentation and route all durable reads/writes through validated native bridge methods. Native SQLite remains authoritative.
- Start with an available on-device model. A hosted model may be used only if the user has explicitly enabled that provider; disclose which selected source details will be sent before the session begins. Never silently upload raw media or switch providers.
- Honor each source's existing AI-inclusion setting. Excluded sources are unavailable to the interviewer. Do not request Photos, Calendar, microphone, or other permissions from the interview flow; the user must first select an already authorized item.
- Keep unsaved interview answers temporary. On explicit save, record the result as user-authored text with source linkage and revision handling; do not save generated questions as user recollections.

## Acceptance gates

- The interview starts only from an explicit user action on a selected photo or event and can be skipped, stopped, edited, or discarded without changing the source.
- Questions refer to the selected source and user answers, stay open-ended, and do not present model guesses as facts.
- A calendar-only plan never becomes evidence of attendance; visual cues never become claims about identity, relationships, precise location, feelings, or unseen activity.
- No answer or AI question enters the journal until the user reviews and explicitly saves the recollection. The saved item retains the user's text, source link, and revision semantics.
- Excluded sources are not processed. Hosted processing, if enabled, sends only the disclosed selected-source data and never falls back silently.
- Evaluate with disposable synthetic photos and calendar events, including ambiguous imagery, an event the user did not attend, skipped questions, discarded sessions, source edits/deletion, provider unavailability, and explicit save. Do not use personal-library access for evaluation.
