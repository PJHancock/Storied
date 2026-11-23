# Photos and calendar connections — 2026-11-12

## Photos

The Workshop Photos switch calls PhotoKit authorization only when it is switched on. On a day page, the app finds assets whose capture date falls within that local calendar day and displays up to 12 resized thumbnails with their local capture time. Limited library authorization works. The app does not copy originals into the journal database or send them to a service. PhotoKit can fetch iCloud Photos assets on demand when the operating system makes them available.

## Calendar

The Workshop Calendar switch requests full EventKit event access. The day page queries events for that date and displays title, start time or all-day state, and optional location. This covers calendars available through Apple Calendar on the device, including Google calendars the user has already added and synced there. The app does not create or change calendar events.

Direct Google Calendar OAuth/API synchronization is still open from the implementation plan. It requires Google OAuth app registration and token storage/sync handling; this build does not claim that direct connector is complete.

## Permission behavior

Reading connection status at launch does not present a prompt. The OS prompt starts only from the matching Workshop toggle. Turning a toggle off disables reads in the app; it does not revoke the system-level permission, which can be revoked in system Settings.

## Verification and limits

The TypeScript/Vite build and macOS Swift package compile passed. Six native service tests and four web tests passed; Info-iOS.plist and the Xcode project lint clean; the packaged Mac app passes strict signature verification. Live permission prompts and real personal libraries were not exercised. The current environment lacks full Xcode, so iPhone compilation and device behavior remain unverified.

## Thumbnail rendering fix

The first build returned PhotoKit thumbnails as `data:image/jpeg;base64,...`, while the bundled Content Security Policy inherited `img-src` from `default-src 'self'`. That blocked the thumbnail images even though the native date query succeeded. `scripts/finish-web.mjs` now explicitly permits `img-src 'self' data:`; external network access remains blocked. A web regression assertion checks this policy, all 4 web tests pass, and the Mac app has been rebuilt. Quit and reopen the app to load the new bundled assets. The current computer-use host could not launch the app for an end-to-end visual check, so real-image display after this fix still needs confirmation in the user's running copy.
