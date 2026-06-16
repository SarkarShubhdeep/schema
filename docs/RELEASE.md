# Release Process

Repeatable workflow for shipping Schema builds to internal TestFlight (macOS).

## Versioning

| Field | Xcode setting | Example |
|-------|---------------|---------|
| Marketing version | `MARKETING_VERSION` | `0.1` |
| Build number | `CURRENT_PROJECT_VERSION` | `1`, `2`, `3`… |

**Rule:** Increment the build number for every TestFlight upload. Change the marketing version only for user-facing releases (e.g. `0.1` → `0.2`).

## Pre-release checklist

Run through [INTERNAL_TESTING.md](INTERNAL_TESTING.md) smoke tests on a **Release** build before archiving.

```bash
xcodebuild \
  -project Schema.xcodeproj \
  -scheme Schema \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

Confirm:

- Build succeeds with no errors
- `Schema.app` shows the correct icon in Finder
- Settings shows the expected version and build

## Archive and upload (Xcode)

### Option A — Xcode Organizer

1. Open `Schema.xcodeproj` in Xcode.
2. Select the **Schema** scheme and **Any Mac (Apple Silicon)** or your Mac as destination.
3. **Product → Archive** (uses Release configuration via shared scheme).
4. In the Organizer, select the archive → **Distribute App**.
5. Choose **App Store Connect** → **Upload**.
6. Confirm the archive is **macOS only** (`Schema.app`) — do not upload an iOS build.
7. Wait for upload and processing to complete.

### Option B — Command line

```bash
# Archive
xcodebuild archive \
  -project Schema.xcodeproj \
  -scheme Schema \
  -configuration Release \
  -archivePath build/Schema.xcarchive \
  -destination 'platform=macOS' \
  -allowProvisioningUpdates

# Export and upload (uses ExportOptions.plist)
xcodebuild -exportArchive \
  -archivePath build/Schema.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates
```

## Enable TestFlight build

1. Open [App Store Connect](https://appstoreconnect.apple.com) → your app → **TestFlight**.
2. Select the **macOS** tab.
3. Wait for the build to finish processing (may take 10–30 minutes).
4. Under **Internal Testing**, add the build to your internal group.
5. Notify testers (they need TestFlight for Mac installed).

## Git release

After a successful upload:

```bash
# Commit all release changes on main
git add -A
git commit -m "Release v0.1.0 for internal TestFlight"

# Tag the release
git tag -a v0.1.0 -m "Schema v0.1.0 — internal TestFlight"

# Push
git push origin main --tags
```

Optional: create a GitHub Release from the `v0.1.0` tag with the [CHANGELOG.md](../CHANGELOG.md) excerpt. TestFlight hosts the binary; no need to attach a `.dmg`.

## Signing notes

- **Team ID:** `Z62938YSA8` (set in `project.pbxproj` as `DEVELOPMENT_TEAM`)
- **Bundle ID:** `com.sarkarshubhdeep.schema`
- **Signing:** Automatic (Xcode manages Apple Distribution certificate for archive)
- **Entitlements:** `Schema/Schema.entitlements` (App Sandbox, user-selected files read-only)
- **Hardened Runtime:** Enabled for Release builds

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Archive button greyed out | Select "Any Mac" as destination, not a simulator |
| Signing error | Xcode → Settings → Accounts → download certificates; confirm team is selected |
| Upload rejected — missing icon | Verify `AppIcon.icon` is in the target and Release build shows an icon |
| Build stuck processing | Wait up to an hour; check email for App Store Connect issues |
| Testers can't see build | Confirm they are internal testers and build is assigned to the internal group |

## iOS (future)

App Store Connect lists iOS, but no iOS target exists yet. Ignore the iOS TestFlight tab until an iOS target is added to the Xcode project.
