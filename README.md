# aipaste

Local-first **clipboard history for macOS**, built for fast daily use from the menu bar.

- **Bundle ID:** `com.eden.aipaste`
- **Product name:** ai paste
- **Platform:** macOS 13+
- **Stack:** SwiftUI + AppKit + SQLite

Clipboard contents stay on this Mac. The current release has no accounts, cloud sync, network upload, or AI processing.

## Features

- Text, image, and mixed text-image clipboard history
- Bottom-of-screen horizontal card gallery with real image thumbnails
- Six workbench skins: Default, Warm Paper, Moss Garden, Graphite, Mist Blue, and Rose Ash
- Search by content, source app, or favorite note
- Source-app and favorites filters
- Content deduplication and automatic capacity pruning
- Favorites that survive history cleanup, with optional notes of up to 10 characters
- Copy-only and automatic paste workflows
- Per-app ignore rules with a running-app/history-app picker
- Configurable global shortcut (default **⇧⌘V**)
- Launch at Login and English / Simplified Chinese UI
- Local SQLite metadata plus local media files only

## Requirements

- macOS 13+
- Full **Xcode** app (not only Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Generate & run

```bash
./scripts/generate-project.sh
open aipaste.xcodeproj
# Product → Run (⌘R)
```

Or from the CLI after generating the project:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' build
```

### Package for trial (share with others)

One command (default output: Desktop):

```bash
./scripts/package-release.sh
# or: ./scripts/package-release.sh ~/Downloads
```

Produces **only**:

- `aipaste-<version>-<YYYYMMDD>.zip` — send this file (contains `aipaste.app` + `试用说明.txt`)

After success the script deletes `build/` intermediates and does **not** leave a bare `.app` next to the zip, so Spotlight is less likely to show many aipaste copies. Pass `KEEP_BUILD=1` to retain intermediates for debugging.

The app is a menu-bar accessory (`LSUIElement`). Look for the clipboard icon in the menu bar; it intentionally has no Dock icon.

## Using the history gallery

Click the menu-bar icon or press **⇧⌘V** to open the gallery on the screen containing the pointer. The shortcut can be changed in Settings.

| Action | Mouse / keyboard |
|--------|------------------|
| Open or close the gallery | Menu-bar icon or **⇧⌘V** |
| Select a card | Click, or **←** / **→** |
| Paste and close | Double-click or **Enter** |
| Copy without pasting | **⌘C** or card context menu |
| Add/remove favorite | **⌘P** or card context menu |
| Add/edit favorite note | Card context menu |
| Delete selected item | Forward Delete (`fn+Delete` on compact keyboards) |
| Close the gallery | **Esc** or click outside |

Use the gallery toolbar to search, filter by source app, show favorites, open Settings, clear history, or quit. Right-clicking the menu-bar icon also opens the app menu.

## Accessibility (auto-paste)

Paste always restores the selected item to the system pasteboard. When Accessibility access is granted, aipaste also sends ⌘V to the previously focused app.

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable **aipaste**
3. Or use **Settings → Accessibility → Open Settings…**

Without permission, the action degrades to copy-only and shows a non-blocking hint. You can then press ⌘V manually; aipaste does not open System Settings or show a modal alert automatically.

## Settings

Settings currently include:

- Workbench skin selection with immediate preview and persistence
- Maximum regular-history size (default: 500)
- Maximum favorites (default: 30)
- Ignored applications, selected from running apps/history or entered by Bundle ID
- Global shortcut recording and reset
- Launch at Login
- English / Simplified Chinese language selection
- Accessibility status and shortcut to System Settings
- Clear history and quit actions

Skins affect only the clipboard workbench. They do not alter stored clipboard data.

## Data path

```
~/Library/Application Support/aipaste/
  db/aipaste.sqlite
  media/          # image data and original pasteboard snapshots
```

Preferences and ignore rules use standard `UserDefaults` (app domain).

Images are stored as local media files. Where available, aipaste also captures the original pasteboard flavors so content from apps such as Lark/Feishu can be restored more faithfully.

## Privacy

- All history is **local-only** on this Mac.
- There is no network upload, account system, or iCloud sync.
- You can ignore apps in Preferences (nothing is ignored by default).
- **Clear History** removes regular history but keeps favorites.
- Favorites can be removed individually from the gallery.

## Tests

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test
```

Manual checklist: [`scripts/manual-smoke.md`](scripts/manual-smoke.md)

The XCTest suite covers storage, deduplication, migration, favorites, filtering, thumbnail loading, ignore rules, shortcut configuration, ingestion, and Accessibility fallback behavior.

## Docs

- Product spec: [`docs/superpowers/specs/2026-07-20-aipaste-design.md`](docs/superpowers/specs/2026-07-20-aipaste-design.md)
- Phase 1 implementation plan: [`docs/superpowers/plans/2026-07-21-aipaste-phase1.md`](docs/superpowers/plans/2026-07-21-aipaste-phase1.md)
- Gallery redesign spec: [`docs/superpowers/specs/2026-07-24-clipboard-gallery-redesign.md`](docs/superpowers/specs/2026-07-24-clipboard-gallery-redesign.md)
- Gallery redesign plan: [`docs/superpowers/plans/2026-07-24-clipboard-gallery-redesign.md`](docs/superpowers/plans/2026-07-24-clipboard-gallery-redesign.md)

## Current non-goals

- AI / summarization / rewrite
- Cloud sync or multi-device
- File and folder clipboard history
- Multiple pinboards or favorites collections
- Mac App Store / sandbox packaging
- Windows or cross-platform support
