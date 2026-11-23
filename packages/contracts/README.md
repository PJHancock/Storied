# Bridge contract version 1

bridge.ts describes request parameters and result types. Every request has exactly version=1, UUID requestId, method and params. Every reply echoes version and requestId and contains result or error(code,message,retryable). The native dispatcher validates methods, parameter keys, booleans, bounded UTF-8 payloads, dates, timezones, UUIDs and revision integers independently of TypeScript.

This is an initial manually maintained contract. Schema-driven code generation and contract drift CI are open phase-1 work, not claimed complete. Methods: system.capabilities, journal.listDays, journal.getDay, journal.createEntry, journal.updateEntry, journal.deleteEntry, draft.get, draft.save. Unknown or incomplete calls fail. JS times out after 15 seconds and warns that completion may have occurred; retrying a create with the same ID and payload cannot duplicate it. Mutation cancellation is not advertised.
