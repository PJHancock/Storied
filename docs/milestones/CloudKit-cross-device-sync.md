# CloudKit cross-device sync

Status: implementation blocked at Apple app provisioning. Planning and an honest in-app setup state are implemented; data synchronization is not active.

## Decision

Keep each device's SQLite vault and managed media directory authoritative for local reads and writes. Add an opt-in CloudKit private-database sync layer for devices signed into the same Apple Account. Do not place a live SQLite database or WAL files in iCloud Drive. CloudKit sync must exchange versioned journal records and original media assets, then apply validated changes through native storage APIs.

## Data scope

Sync user-authored text entries and drafts, uploaded original media and its metadata, user-authored day heading overrides, and AI summary guidance. People and Events context records and their day links are explicitly out of scope for the first sync release; revisit them if that feature is completed later. Do not sync Photos or Calendar authorization, their connected-source caches, weather responses, local embeddings, generated summary caches, OpenAI credentials, or other device-specific permissions/secrets. A city preference can be added to the sync contract after it moves from browser local storage into native storage.

## Conflict and deletion rules

- Use stable record IDs, schema versions, source revisions, and durable deletion tombstones.
- Detect concurrent edits and preserve both versions or ask the user to resolve them. Never silently overwrite an original memory based only on device clock time.
- Media transfers use content hashes, resumable bounded assets, and verification before a record is made visible locally.
- A sync failure never prevents local reads/writes. Disabling sync stops future transfers; it does not delete the local vault or imply cloud erasure.
- Present account, network, quota, and CloudKit errors with retry guidance. Persist CloudKit sync-engine state in the local vault.

## Implementation slices

1. Document the architecture, data scope, and provisioning gates; expose the unconfigured state honestly in Settings. **Implemented.**
2. Configure an Apple Developer team, registered bundle IDs, CloudKit container, iCloud capability, CloudKit and remote-notification entitlements for iOS and macOS targets. **Blocked: no team, container ID, or signed app profile is present in this workspace.**
3. Implement the native CloudKit sync engine, local outbox/tombstones, versioned record codecs, media assets, opt-in and sync controls.
4. Evaluate with disposable synthetic vaults on two signed devices/accounts-in-same-Apple-Account; cover offline edits, simultaneous edits, deletion, large media, retry, quota, opt-out and interrupted transfer.

## Acceptance gates

- SQLite remains the only local source of truth; sync work is applied through native APIs.
- No permission/account query is triggered at app launch. The user explicitly enables sync first.
- Only the data scope above is transferred; People and Events records and day links are checked as exclusions, while AI summary guidance is checked as included data.
- Conflicts and deletion propagate without loss; interrupted media never appears complete.
- Same-account iPhone/Mac round trip succeeds with no access to real journals during evaluation.
- Build/signing evidence and physical-device evidence are recorded separately. Do not call the feature complete before all gates pass.

## Current provisioning evidence

The app project has placeholder bundle identifiers (`org.example.MemoryCatcher3` and `org.example.MemoryCatcher3.Development`), no Apple Development team, no CloudKit container, and no iCloud entitlements. The macOS packaging script ad-hoc signs the development app. Those artifacts cannot authenticate to a private CloudKit database. CloudKit runtime sync and two-device behavior therefore cannot be verified until the project is registered and signed under the user's Apple Developer team.
