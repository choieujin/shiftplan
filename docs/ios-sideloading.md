# Installing a Flutter app on iPhone without a paid developer account

How this project gets onto a physical iPhone with **no Apple Developer Program ($99/yr)** and **no local Xcode install**. Written after setting this up for ShiftPlan (2026-07); everything below was verified on macOS 13.5 + iPhone (iOS 17+).

## Architecture

```
GitHub Actions (macos runner, Xcode preinstalled)
  └─ flutter build ios --no-codesign  →  unsigned shiftplan.ipa (artifact)
        └─ download to Mac → copy to iCloud Drive
              └─ iPhone: AltStore "+" → picks .ipa
                    └─ AltStore → AltServer (Mac) → Apple signing service
                          └─ 7-day free-account signature → installed
```

Key insight: the .ipa does **not** need to be signed locally. AltStore re-signs it
with a free Apple ID at install time, so the build machine never needs
certificates — which means CI can build it, and the local Mac never needs Xcode.

## Why cloud build (project-specific constraints)

- macOS 13 caps Xcode at 15.2 and current Flutter's Dart VM requires macOS 14+.
  Local toolchain: Flutter 3.29.3 manually installed at `~/development/flutter`
  (not on PATH — `export PATH="$HOME/development/flutter/bin:$PATH"` first).
- GitHub macOS runners are **free for public repos** and ship with Xcode.
- An app built with an older iOS SDK still installs and runs on newer iOS,
  because AltStore installs it directly — Xcode's "device support files"
  restriction only applies to deploying via Xcode.

## The CI workflow

See [.github/workflows/ios-ipa.yml](../.github/workflows/ios-ipa.yml). Steps that matter:

1. `flutter build ios --release --no-codesign` — produces `Runner.app` with no signature.
2. A Ruby script (`scripts/add_widget_target.rb`, using the `xcodeproj` gem)
   injects the WidgetKit extension target into the generated Xcode project,
   since `flutter create` does not know about extensions.
3. **Ad-hoc signing with entitlements**: an unsigned binary carries no
   entitlements, so AltStore cannot see the App Group needed by the home
   widget. `codesign --force -s - --entitlements ...` embeds them; AltStore
   replaces the ad-hoc signature but keeps the entitlements.
4. Zip `Payload/Runner.app` → `shiftplan.ipa` → upload as artifact.

Download a build: `gh run download <run-id> --name shiftplan-ipa --dir ~/Downloads/shiftplan-ipa`

## One-time setup

### Mac
1. `brew install --cask altserver`, launch it.
   **AltServer is a menu-bar-only app** — no window, no Dock icon. Look for a
   hollow diamond (◇) at the top-right of the screen. Clicking the app in
   Launchpad/Dock does nothing (that's expected, not a bug).
2. Add AltServer to login items so it survives reboots.

### Apple ID
Create an **app-specific password** at account.apple.com → Sign-in & Security.
Use it everywhere instead of the real password; it can be revoked independently
and cannot bypass 2FA. Credentials go to Apple's auth servers only (AltStore is
open source and auditable).

### iPhone
1. Connect via **USB** (data cable, not charge-only), unlock, tap "Trust".
2. Menu bar ◇ → **Install AltStore** → pick the device → Apple ID + app password.
3. iPhone: Settings → General → VPN & Device Management → trust your Apple ID.
4. iPhone: Settings → Privacy & Security → **Developer Mode** → on → reboot →
   confirm. (Required since iOS 16 for dev-signed apps; it's an official Apple
   switch, not a jailbreak.)
5. Settings → Privacy & Security → Local Network → make sure **AltStore** is on.

## Installing / updating the app

1. Get `shiftplan.ipa` (CI artifact) onto the Mac.
2. Copy it to iCloud Drive: `cp shiftplan.ipa ~/Library/Mobile\ Documents/com~apple~CloudDocs/`
   (shows up in the iPhone Files app automatically; more reliable than AirDrop).
3. On iPhone: open **AltStore → My Apps → "+"** → browse to iCloud Drive → pick the .ipa.
   Same Wi-Fi as the Mac (or USB) required — AltServer does the actual signing.
4. Updates are the same flow; AltStore installs over the old version, data intact.

**Never tap the .ipa in the Files app directly** — iOS will try to install it
as-is and fail with "integrity could not be verified". Installation must go
through AltStore's "+" button.

## Free-account limits

- Signature expires after **7 days**. AltStore auto-refreshes in the background
  whenever the iPhone and the Mac (running AltServer) share a Wi-Fi network.
- Max **3 sideloaded apps** installed at once.
- Max **10 App IDs per 7 days** (each new bundle ID burns one — keep the bundle
  ID stable across builds).

## Troubleshooting (all hit in practice)

| Symptom | Cause | Fix |
|---|---|---|
| Clicking AltServer "does nothing" | Clicking the Launchpad/Dock icon — it's a menu-bar app | Click the ◇ in the menu bar (top-right, same row as the clock) |
| ◇ icon missing from menu bar | Status item occasionally fails to appear | `pkill -x AltServer && open -a AltServer` |
| `AltStore.OperationError 1200` (server not found) even on same Wi-Fi | AltServer's Bonjour advertising silently died | Restart AltServer. Verify with `dns-sd -B _altserver._tcp local` (needs a tty — run via `script -q /dev/null …` if scripted); your Mac's name should be listed |
| "This app could not be installed: integrity could not be verified" | Tapped the .ipa directly in Files/Safari | Install via AltStore "+" only |
| `The name " " contains invalid characters` during install | Non-ASCII `CFBundleDisplayName` (e.g. Korean) — Apple's App ID registration rejects it | Keep `CFBundleDisplayName` ASCII (`ShiftPlan`); localize the visible name via `InfoPlist.strings` if needed |
| AltStore won't open after install | Developer profile not trusted / Developer Mode off | See one-time iPhone setup steps 3–4 |
| Refresh stopped working after a week | Mac asleep/AltServer not running/different network | Start AltServer, join same Wi-Fi, pull-to-refresh in AltStore; restart AltServer first if it still fails |

## Alternatives considered

- **PWA** (`flutter build web` + hosting): zero Apple friction, no expiry, but
  no home-screen widget and no native feel.
- **Sideloadly**: has a real window UI (easier than the menu-bar hunt), but
  closed source — worse fit when the Apple ID privacy story matters.
- **Paid developer account**: removes the 7-day limit (TestFlight/ad-hoc), $99/yr.
