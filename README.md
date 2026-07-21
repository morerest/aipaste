# clipai

Local macOS **clipboard history** for personal daily use (Phase 1).

- **Bundle ID:** `com.eden.clipai`
- **Product name:** clipai
- **Scope:** text + image history, search, paste (with Accessibility degrade), ignore list, capacity prune, local SQLite only

Phase 1 does **not** upload clipboard contents. No AI, no cloud sync, no file clipboard, no pinboard.

## Requirements

- macOS 13+
- Full **Xcode** app (not only Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Generate & run

```bash
./scripts/generate-project.sh
open clipai.xcodeproj
# Product → Run (⌘R)
```

Or from the CLI after generating the project:

```bash
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' build
```

The app is a menu-bar accessory (`LSUIElement`). Look for **clipai** in the status bar (no Dock icon).

## Hotkey

| Action | Shortcut |
|--------|----------|
| Toggle history panel | **⇧⌘V** (Shift + Command + V) |

Also: status-item menu → **Show History** / **Preferences…** / **Quit clipai**.

Hotkey rebinding UI is deferred (fixed ⇧⌘V in Phase 1).

## Accessibility (auto-paste)

Paste writes the snippet to the system pasteboard and, if allowed, posts ⌘V into the frontmost app.

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable **clipai**
3. Or use **Preferences → Open Accessibility Settings**

If Accessibility is **not** granted, Paste **degrades to copy-only**: content is on the clipboard and a short status message asks you to press ⌘V yourself.

## Data path

```
~/Library/Application Support/clipai/
  db/clipai.sqlite
  media/          # image blobs
```

Preferences and ignore rules use UserDefaults suite `com.eden.clipai`.

## Privacy

- All history is **local-only** on this Mac.
- Phase 1 has **no network upload**, no accounts, no iCloud sync.
- You can ignore apps by bundle ID (password managers are seeded by default).
- Clear history from Preferences at any time.

## Tests

```bash
./scripts/generate-project.sh
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' test
```

Manual checklist: [`scripts/manual-smoke.md`](scripts/manual-smoke.md)

## Docs

- Spec: [`docs/superpowers/specs/2026-07-20-clipai-design.md`](docs/superpowers/specs/2026-07-20-clipai-design.md)
- Plan: [`docs/superpowers/plans/2026-07-21-clipai-phase1.md`](docs/superpowers/plans/2026-07-21-clipai-phase1.md)

## Phase 1 non-goals

- AI / summarization / rewrite
- Cloud sync or multi-device
- File / URL-rich clipboard beyond text + images
- Pinboard / favorites collections
- Mac App Store / sandbox packaging
- Custom hotkey recorder UI
