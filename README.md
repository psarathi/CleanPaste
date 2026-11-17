# CleanPaste

A native macOS clipboard manager built with SwiftUI and AppKit, featuring a frosted bottom-edge shelf, app-colored visual cards, Pinboards, Paste Stack, Quick Look previews, and Direct Paste.

## Features

- **Frosted Bottom Shelf (`⇧⌘V`):** Borderless, non-activating `NSPanel` with behind-window vibrancy that slides up along the bottom edge of the active screen and remembers the frontmost application.
- **Visual Cards by Content Type:**
  - **Text / Code / Rich Text:** Preserves RTF & HTML formatting (or pastes stripped plain text via `⇧↩` / `⇧⌘1–9`), with automatic monospace rendering for code snippets.
  - **Links:** Fetches page titles, favicons, and preview images asynchronously via `LinkPresentation` (`LPMetadataProvider`).
  - **Images:** Stores full-resolution payloads as external blobs with downsampled `560px` thumbnails and transparency checkerboards.
  - **Colors:** Detects Hex (`#RGB`, `#RRGGBB`, `#RRGGBBAA`), `rgb()`/`rgba()`, and `hsl()`/`hsla()`, displaying live color swatches with one-click Hex, RGB, HSL, and SwiftUI `Color` copy actions.
  - **Files:** Displays Finder icons and Quick Look thumbnails (`QLThumbnailGenerator`) with multi-file badges and Reveal in Finder.
- **App-Colored Card Headers:** Samples the source app's icon to derive balanced header colors with live relative timestamps and `⌘1`–`⌘9` quick-paste badges.
- **Pinboards & Dynamic Snippets:** Organize permanent clips into color-coded tabs above the shelf; drag cards onto tabs to pin them, or drag cards directly into external apps. Pinned items never expire with history retention rules and support paste-time placeholders (`{{date}}`, `{{time}}`, `{{datetime}}`, `{{uuid}}`, `{{clipboard}}`).
- **One-Click Transforms:** Transform & Paste or Transform & Copy right from card context menus or Quick Look—including `UPPERCASE`/`lowercase`/`Title Case`/`camelCase`/`snake_case`, Trim Whitespace, Join Lines, Pretty/Minify JSON, Base64 Encode/Decode, and stripping URL tracking query parameters.
- **Paste Stack (`⇧⌘C`):** Queue multiple copied snippets in FIFO or LIFO order with a shelf strip and floating HUD, auto-advancing on `⌘V` when Accessibility is granted (or via `⌥⌘V`).
- **Quick Look & Editing:** Press `Space` to preview any clip (`⌘E` to edit text, `⌘R` to rename, `⌫` to delete with `⌘Z` undo).
- **Direct Paste & Terminal Safety:** Supports optional single-click direct paste (in addition to `Return`, `⌘1–9`, and double-click) plus **Terminal-safe paste**, stripping trailing `\r`/`\n` when pasting into Terminal, iTerm2, Warp, WezTerm, Alacritty, kitty, Ghostty, or Hyper.
- **Privacy, Secret Masking & Timed Pause:** Skips concealed/transient password-manager clipboard types (`org.nspasteboard.ConcealedType`, `TransientType`, etc.), detects API keys/tokens/JWTs/PEM keys (`Mask Preview`, `Ignore & Skip`, or `Off`), supports an excluded-apps list, and lets you pause recording indefinitely or for **15 minutes / 1 hour** with automatic resume.
- **Vision Image OCR & Search:** Automatically runs on-device Apple Vision text recognition (`VNRecognizeTextRequest`) on captured images so text inside screenshots is searchable alongside text clips, with an OCR match pill and **Copy Text from Image** / **Paste Text from Image** actions.
- **App & Date Filters + Match Highlighting:** Narrow the shelf by source app (via the filter bar, overflow menu, card context menu, or clicking a card's header app icon) and date (`Today`, `Last 7 Days`, `Last 30 Days`), with live case-insensitive search highlighting.
- **Menu Bar Icon Switcher:** Includes 7 selectable menu bar icon styles (`PasteBoard`, `Coral Cards`, `Spectrum Fan`, `Sapphire Mini`, `Teal Clipboard`, `Indigo & Cyan`, and `Monochrome`).

## Requirements

- macOS 14.0+
- Xcode / Swift 6 toolchain

## Building & Running

Build the standalone `.app` bundle and run unit tests:

```bash
# Run unit tests
swift test

# Build, bundle, and sign build/CleanPaste.app
# (Auto-detects an Apple Development certificate in Keychain, or falls back to ad-hoc signing)
./scripts/build_app.sh

# Install to /Applications and launch
rm -rf /Applications/CleanPaste.app
cp -R build/CleanPaste.app /Applications/CleanPaste.app
open /Applications/CleanPaste.app
```

### Direct Paste & Accessibility Permission

For **Direct Paste** (automatically sending `⌘V` into the active app) and **Paste Stack auto-advance**, grant Accessibility access to `/Applications/CleanPaste.app` in **System Settings → Privacy & Security → Accessibility**.

> **Tip — Preserve Accessibility permission across rebuilds:** `scripts/build_app.sh` automatically signs `CleanPaste.app` with your Keychain's **Apple Development** certificate if present (replaceable via `CODESIGN_IDENTITY`), which gives the app a stable Designated Requirement so macOS keeps Accessibility permission across rebuilds. You can create a free certificate in **Xcode → Settings → Accounts → Manage Certificates… → `+` → Apple Development**. If no certificate is found, `build_app.sh` falls back to ad-hoc signing (`codesign --sign -`), which requires removing (`−`) and re-adding (`+`) `CleanPaste.app` in Accessibility Settings after each rebuild.

## Default Shortcuts

| Shortcut | Action |
| --- | --- |
| `⇧⌘V` | Show / Hide CleanPaste shelf |
| `⇧⌘C` | Toggle Paste Stack mode |
| `⌥⌘V` | Paste next item from Paste Stack |
| `⌘1` – `⌘9` | Quick Paste card 1–9 |
| `⇧⌘1` – `⇧⌘9` | Quick Paste card 1–9 as Plain Text |
| `←` / `→` / `Home` / `End` | Navigate cards |
| `⌘←` / `⌘→` | Switch between Clipboard History and Pinboards |
| `↩` / `⇧↩` | Paste / Paste as Plain Text |
| `Space` | Toggle Quick Look preview |
| `⌘E` / `⌘R` / `⌘C` | Edit / Rename / Copy selected clip |
| `⌫` / `⌘Z` | Delete selected clip / Undo delete |
| Type any character | Instant type-to-search |
| `Esc` | Clear search or dismiss shelf |

## License

Released under the [MIT License](LICENSE).

