# aipaste — Manual smoke checklist

Use this checklist after building and running aipaste from Xcode. Tick each item only after observing the described behavior.

## Prerequisites

- [ ] Generate the project: `./scripts/generate-project.sh`
- [ ] Build and run aipaste from Xcode
- [ ] Open TextEdit or Notes as a paste target
- [ ] Copy at least one text item and one image or screenshot

## Gallery and menu bar

- [ ] Menu bar shows a monochrome clipboard icon in light and dark mode
- [ ] Clicking the icon directly opens and closes the history gallery
- [ ] ⇧⌘V opens a bottom horizontal card strip on the active screen
- [ ] The gallery has no old bottom-row Paste, Copy, Delete, or Close buttons
- [ ] Text cards show content, source, and time; image cards show real thumbnails
- [ ] Newest clipboard records appear first
- [ ] Searching filters the visible cards and a no-results state appears when nothing matches
- [ ] The All Apps menu lists source apps from history and filters cards to the chosen app
- [ ] App filter and text search can be used together
- [ ] Favorites chip toggles between All and Favorites; empty favorites shows guidance
- [ ] Card context menu can Add to Favorites / Remove Favorite; pinned cards show a star
- [ ] Pinned cards support Add/Edit Note… (≤10 chars); note replaces app name in meta (icon kept); hover shows source app
- [ ] ⌘P toggles favorite on the selected card; over-cap shows a status message
- [ ] Clear history keeps favorites; unpinned items are removed
- [ ] Settings → Maximum favorites defaults to 30 and can be changed
- [ ] The gallery shows an empty state when history is empty

## Keyboard, pointer, and card actions

- [ ] Left/Right changes selection and scrolls the selected card into view
- [ ] Single-clicking a card selects it immediately (no delayed highlight)
- [ ] Enter pastes the selected card and closes the gallery
- [ ] Double-clicking a card pastes it and closes the gallery
- [ ] Command-C copies the selected card without closing the gallery
- [ ] Forward Delete removes the selected card (`fn+Delete` on compact Mac keyboards); Backspace still edits the search field
- [ ] Esc closes the gallery
- [ ] Clicking outside the gallery (desktop or another app) dismisses it
- [ ] Opening the overflow or card context menu does not dismiss the gallery
- [ ] A card context menu supports Copy and Delete

## Accessibility behavior

- [ ] With Accessibility permission granted, Enter or double-click pastes into the previous app automatically
- [ ] With Accessibility permission denied, paste degrades to copy and the gallery shows a non-modal explanation and Open Settings action
- [ ] The denied-permission path never shows a blocking alert
- [ ] After the degraded copy, manually pressing ⌘V in the target app pastes the expected content

## Overflow menu

- [ ] Settings is reachable from the overflow menu and opens Preferences
- [ ] Clear History is reachable from the overflow menu and requires confirmation
- [ ] Quit is reachable from the overflow menu and ends the process cleanly

## Existing behavior regression

- [ ] Copying the same text twice leaves one history record for that content (its time may update)
- [ ] Preferences → Privacy shows ignored apps with **friendly names** and icons (not raw Bundle IDs only)
- [ ] **Add App…** menu lists running apps and apps seen in history; picking one adds it without typing a Bundle ID
- [ ] **Enter Bundle ID** still works for advanced manual entry
- [ ] Preferences ignore rules prevent records from the configured app and work again after removal
- [ ] History survives quitting and relaunching under `~/Library/Application Support/aipaste/`
- [ ] Setting a low maximum-item limit prunes the oldest records after the limit is exceeded
- [ ] Launch at Login can be toggled without crashing (full SMAppService behavior may require a signed build)
- [ ] aipaste remains a menu-bar accessory without a Dock icon

## Automated checks

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' clean build
```

Done when every applicable manual item passes, the test command reports `** TEST SUCCEEDED **` with zero failures, and the clean build reports `** BUILD SUCCEEDED **`.
