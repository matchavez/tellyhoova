# memory.md — matchavez/tellyhoova

Self-context for Claude. README.md is thorough and user-facing (install, prerequisites, Gatekeeper notes, usage). This file adds structural + release notes. Last refreshed: 2026-07-14.

## What this repo is
Native macOS SwiftUI app, a GUI frontend for `yt-dlp` (paste URL → pick quality preset → Get). Requires yt-dlp + ffmpeg installed separately (auto-detects Homebrew paths). macOS ≥ Sequoia. Distributed via Homebrew cask (tap: matchavez/homebrew-tellyhoova) or direct `.dmg` download from Releases.

## Layout
`Tellyhoova/` (ContentView.swift, TellyhoovApp.swift, `Models/`, `Services/`, `Views/`), `Tellyhoova.xcodeproj` (generated via XcodeGen from `project.yml` — don't hand-edit the xcodeproj if `project.yml` changes, regenerate with `xcodegen generate`), `Tellyhoova-1.0.{0,1,2,3,4}.dmg` — **note: these DMGs are committed directly to the repo root in addition to being attached as GitHub Release assets** (verified both exist for all 5 versions) — that's redundant repo bloat but appears intentional/unchanged across releases, not something to "clean up" without asking.

## Release process (reconstructed 2026-07-14, no CI/scripts exist — all manual)
1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, run `xcodegen generate`.
2. `xcodebuild -project Tellyhoova.xcodeproj -scheme Tellyhoova -configuration Release -derivedDataPath build build`.
3. Stage `build/Build/Products/Release/Tellyhoova.app` + a symlink to `/Applications` in a temp folder, then `hdiutil create -volname Tellyhoova -srcfolder <staging> -ov -format UDZO Tellyhoova-X.Y.Z.dmg`. App is unsigned/adhoc (matches `CODE_SIGNING_ALLOWED: NO` in project.yml) — consistent with the Gatekeeper caveat in the README.
4. Update README changelog + any preset/feature tables, commit everything including the new dmg, tag `vX.Y.Z`, push commit + tag.
5. `gh release create vX.Y.Z Tellyhoova-X.Y.Z.dmg --title "Tellyhoova X.Y.Z" --notes "..."`.
6. Bump the cask in **matchavez/homebrew-tellyhoova** (version + sha256 of the new dmg) — separate repo, don't forget it.

## Release history / notable fixes
- 1.0.0 (2026-05-28) → 1.0.1 (Gatekeeper "damaged" caveat + quarantine-strip guidance) → 1.0.2 (themes, quality picker, dock icon/window-close fixes) → 1.0.3 (2026-06-20: fixed long-download hang + memory growth, wired bundle version to project version) → 1.0.4 (2026-07-14: added Audio Only (M4A) preset; fixed Audio Only (MP3) silently outputting Opus by finally passing `--audio-format` to yt-dlp).
- Notification permission request was moved to app init and uses provisional authorization (App Store-less deployment nuance) with a "Glass" sound fallback if the system sound is unavailable.
- The homebrew-tellyhoova cask now auto-strips quarantine on install (`postflight` xattr strip) so most users never see the Gatekeeper dialog described in the README.

## Related repos
- **matchavez/homebrew-tellyhoova** — Homebrew tap distributing this app's releases; bump it whenever a new version ships here.
- **matchavez/matchavez.github.io** — has a `projects/tellyhoova.md` page linking here.

## Sync note
Keep this file and README.md in sync with every meaningful change. If they drift, flag it to Mat and get approval before publishing the sync rather than doing it silently.
