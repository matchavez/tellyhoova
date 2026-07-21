# memory.md — matchavez/tellyhoova

Self-context for Claude. README.md is thorough and user-facing (install, prerequisites, Gatekeeper notes, usage). This file adds structural + release notes. Last refreshed: 2026-07-22.

## What this repo is
Native macOS SwiftUI app, a GUI frontend for `yt-dlp` (paste URL → pick quality preset → Get). Requires yt-dlp + ffmpeg installed separately (auto-detects Homebrew paths). macOS ≥ Sequoia. Distributed via Homebrew cask (tap: matchavez/homebrew-tellyhoova) or direct `.dmg` download from Releases.

## Layout
`Tellyhoova/` (ContentView.swift, TellyhoovApp.swift, `Models/`, `Services/`, `Views/`), `Tellyhoova.xcodeproj` (generated via XcodeGen from `project.yml` — don't hand-edit the xcodeproj if `project.yml` changes, regenerate with `xcodegen generate`; `sources: - path: Tellyhoova` in project.yml is a directory scan, so new files under `Tellyhoova/` are picked up automatically on regenerate, no manual pbxproj surgery needed), `Tellyhoova-1.0.{0..8}.dmg` — **note: these DMGs are committed directly to the repo root in addition to being attached as GitHub Release assets** (verified both exist across versions) — that's redundant repo bloat but appears intentional/unchanged across releases, not something to "clean up" without asking.

## Release process (reconstructed 2026-07-14, no CI/scripts exist — all manual)
1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, run `xcodegen generate`.
2. `xcodebuild -project Tellyhoova.xcodeproj -scheme Tellyhoova -configuration Release -derivedDataPath build build`.
3. Stage `build/Build/Products/Release/Tellyhoova.app` + a symlink to `/Applications` in a temp folder, then `hdiutil create -volname Tellyhoova -srcfolder <staging> -ov -format UDZO Tellyhoova-X.Y.Z.dmg`. App is unsigned/adhoc (matches `CODE_SIGNING_ALLOWED: NO` in project.yml) — consistent with the Gatekeeper caveat in the README.
4. Update README changelog + any preset/feature tables, commit everything including the new dmg, tag `vX.Y.Z`, push commit + tag.
5. `gh release create vX.Y.Z Tellyhoova-X.Y.Z.dmg --title "Tellyhoova X.Y.Z" --notes "..."`.
6. Bump the cask in **matchavez/homebrew-tellyhoova** (version + sha256 of the new dmg) — separate repo, don't forget it.

## Release history / notable fixes
- 1.0.0 (2026-05-28) → 1.0.1 (Gatekeeper "damaged" caveat + quarantine-strip guidance) → 1.0.2 (themes, quality picker, dock icon/window-close fixes) → 1.0.3 (2026-06-20: fixed long-download hang + memory growth, wired bundle version to project version) → 1.0.4 (2026-07-14: added Audio Only (M4A) preset; fixed Audio Only (MP3) silently outputting Opus by finally passing `--audio-format` to yt-dlp) → 1.0.5 (2026-07-14: added adjustable Audio bitrate setting (128–320kbps) since yt-dlp's default VBR quality could land as low as 64kbps on quiet source audio; M4A/MP3 presets now grab the true best-available audio stream before transcoding instead of restricting to a same-extension source stream) → 1.0.6 (2026-07-14: added V0 (best VBR) option to the Audio bitrate picker — LAME's highest-quality VBR preset, passed to yt-dlp as `--audio-quality 0` alongside the existing fixed-kbps options) → 1.0.7 (2026-07-14: added a toolbar gear button between "Show in Finder" and the quality preset dropdown, opening the same `.sheet`-based Settings as the URL-field gear icon — note the sheet has a noticeable few-second delay before it visually animates in on Debug builds, not a functional bug) → 1.0.8 (2026-07-22: diagnosed a real user-reported failure — an audio-only download reported Failed even though extraction had finished, because the embed-thumbnail postprocessor needs Pillow inside yt-dlp's own Homebrew venv (not system Python) to convert WebP thumbnails for MP4/M4A cover art. Added a Dependencies settings tab (`Services/DependencyManager.swift`) replacing Advanced, checking yt-dlp/ffmpeg/Pillow/Homebrew with one-click Install buttons that stream live process output; Pillow's check resolves yt-dlp's actual interpreter from its shebang rather than assuming system Python. Gear icon shows a red badge when something's missing).
- Notification permission request was moved to app init and uses provisional authorization (App Store-less deployment nuance) with a "Glass" sound fallback if the system sound is unavailable.
- The homebrew-tellyhoova cask now auto-strips quarantine on install (`postflight` xattr strip) so most users never see the Gatekeeper dialog described in the README.

## Related repos
- **matchavez/homebrew-tellyhoova** — Homebrew tap distributing this app's releases; bump it whenever a new version ships here.
- **matchavez/matchavez.github.io** — has a `projects/tellyhoova.md` page linking here.

## Sync note
Keep this file and README.md in sync with every meaningful change. If they drift, flag it to Mat and get approval before publishing the sync rather than doing it silently.
