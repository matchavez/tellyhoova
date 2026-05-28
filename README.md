# Tellyhoova 📺

A native macOS app for downloading videos and audio using [yt-dlp](https://github.com/yt-dlp/yt-dlp). Paste a URL, choose a quality preset, and hit **Get** — Tellyhoova handles the rest.

---

## Prerequisites

### yt-dlp

Tellyhoova is a graphical front-end for yt-dlp. **yt-dlp must be installed separately before any downloads will work.**

The easiest way is via [Homebrew](https://brew.sh):

```bash
brew install yt-dlp
```

Tellyhoova automatically detects yt-dlp at the standard Homebrew locations:

| Mac architecture | Default path |
|---|---|
| Apple Silicon | `/opt/homebrew/bin/yt-dlp` |
| Intel | `/usr/local/bin/yt-dlp` |

If you installed yt-dlp somewhere else, update the path in **Settings → Advanced**.

### ffmpeg (recommended)

Many format merging and post-processing features (thumbnail embedding, metadata, SponsorBlock) require ffmpeg. Install it alongside yt-dlp:

```bash
brew install ffmpeg
```

### System requirements

- macOS 15 Sequoia or later
- Apple Silicon or Intel Mac

---

## Installation

Tellyhoova is built from source using Xcode. A pre-built release is not currently distributed.

### Build from source

1. Clone the repository:

   ```bash
   git clone https://github.com/matchavez/tellyhoova.git
   cd tellyhoova
   ```

2. Generate the Xcode project (requires [XcodeGen](https://github.com/yonaskolb/XcodeGen)):

   ```bash
   brew install xcodegen
   xcodegen generate
   ```

3. Open `Tellyhoova.xcodeproj` in Xcode and run with **⌘R**, or build from the command line:

   ```bash
   xcodebuild -project Tellyhoova.xcodeproj -scheme Tellyhoova -configuration Debug build
   ```

The app is unsigned by design, so Gatekeeper may prompt you the first time you launch it. Right-click → Open to proceed.

---

## Usage

1. **Paste a URL** into the text field at the top of the window.
2. **Choose a quality preset** from the dropdown menu in the toolbar row.
3. Press **Get** (or **⌘↩**) to start the download.
4. Watch progress in the queue below. Expand the log for detailed yt-dlp output.
5. Press **Show in Finder** to open the download folder when done.

### Playlists

When you submit a playlist URL, Tellyhoova detects the item count and asks whether you want to download the entire playlist or just the first item.

### Notifications

Tellyhoova posts a system notification when each download completes. Grant notification permission when prompted, or enable it later in **System Settings → Notifications → Tellyhoova**. Notifications can be turned off in **Settings → Output**.

---

## Quality presets

| Preset | What you get | Plays in QuickTime? |
|---|---|---|
| **QuickTime Compatible** | H.264 video (≤ 1080p) + AAC audio | Yes |
| **Best Quality** | Highest available resolution and bitrate (may be VP9/AV1 at 4K+) | No — use VLC or IINA |
| **Best ≤ 1080p** | Best stream at or below 1080p | No |
| **Best ≤ 720p** | Best stream at or below 720p | No |
| **Best ≤ 480p** | Best stream at or below 480p | No |
| **Audio Only (best)** | Best available audio, no video | — |
| **Audio Only (MP3)** | MP3 audio, no video | — |
| **Custom…** | Enter any yt-dlp `-f` format string | Depends on format |

---

## Settings

Open settings with the **⚙** gear icon in the URL bar, or via **⌘,**.

### Format

- **Quality preset** — choose from the table above, or enter a custom yt-dlp format string.
- **Embed thumbnail** — writes the video thumbnail into the file (requires ffmpeg).
- **Embed metadata** — writes title, uploader, and other metadata into the file.
- **Remove SponsorBlock segments** — strips sponsored segments using the SponsorBlock database (requires ffmpeg).

### Output

- **Download folder** — where files are saved. Defaults to `~/Downloads`.
- **Filename template** — yt-dlp output template. Default is `%(title)s.%(ext)s`. See the [yt-dlp output template docs](https://github.com/yt-dlp/yt-dlp#output-template) for available fields.
- **Notifications** — toggle completion notifications on or off.

### Subtitles

- **Download subtitles** — fetch subtitle files alongside the video.
- **Languages** — comma-separated list of language codes (e.g. `en,fr,es`).
- **Include auto-generated subtitles** — also download auto-captions where available.

### Network

- **Rate limit** — cap download speed (e.g. `2M` for 2 MB/s, `500K` for 500 KB/s). Leave blank for unlimited.
- **Retries** — number of times yt-dlp retries a failed fragment (default: 10).
- **Concurrent fragments** — parallel fragment downloads (default: 1). Increasing this can speed up segmented streams.

### Advanced

- **yt-dlp path** — full path to the yt-dlp executable. A green dot confirms yt-dlp is found at that path.

---

## Themes

Tellyhoova ships with three colour themes, selectable in **Settings → Format**:

| Theme | Character |
|---|---|
| **Studio Slate** | Dark blue-grey with blue accent |
| **Signal Amber** | Dark warm-brown with amber accent |
| **Aurora** | Deep indigo with teal accent |

---

## Troubleshooting

**Downloads fail immediately with "yt-dlp missing"**
Install yt-dlp (`brew install yt-dlp`) and confirm the path shown in **Settings → Advanced** points to the binary.

**Downloads complete but the file won't open in QuickTime**
Switch to the **QuickTime Compatible** preset. Best Quality and resolution-capped presets may produce VP9 or AV1 files that QuickTime cannot play. Use [VLC](https://www.videolan.org/vlc/) or [IINA](https://iina.io) instead.

**Thumbnail or metadata embedding fails**
These features require ffmpeg. Install it with `brew install ffmpeg`.

**No completion notification appears**
Check that notifications are enabled in **Settings → Output** and that macOS has permission in **System Settings → Notifications → Tellyhoova**.

---

## License

MIT
