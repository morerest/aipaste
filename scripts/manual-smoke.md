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
- [ ] The card area has no floating navigation button and no card is covered by toolbar chrome
- [ ] Horizontal scrolling uses the native macOS indicator and follows the system scrollbar preference
- [ ] Searching filters the visible cards and a no-results state appears when nothing matches
- [ ] The centered toolbar shows search/count, an independent Favorites star, and one Filters button; it does not shift when contextual navigation appears
- [ ] Clicking the Favorites star toggles Favorites Only in one step without opening a menu or popover; empty favorites shows guidance and the active star remains visible
- [ ] Filters opens a 360pt native popover with a horizontal All / Text / Images / Mixed selector and a direct two-column Source App list
- [ ] Content type combines correctly with search, source-app, and favorites filters while the popover remains open
- [ ] Choosing a source app takes only Open Filters → Click App; no second menu appears
- [ ] The Source App grid lists apps from history with icons, names, selected checks, and 32pt clickable rows
- [ ] A long Source App list scrolls only inside its own region, whose maximum height is 232pt
- [ ] App filter and text search can be used together
- [ ] Filters badge counts only content type and source app (0–2), never search text or Favorites Only
- [ ] Clear Filters appears only for content-type/source-app filters, preserves search text and Favorites Only, and leaves the popover open
- [ ] Card context menu can Add to Favorites / Remove Favorite; pinned cards show a star
- [ ] Pinned cards support Add/Edit Note… (≤10 chars); note replaces app name in meta (icon kept); hover shows source app
- [ ] ⌘P toggles favorite on the selected card; over-cap shows a status message
- [ ] Clear history keeps favorites; unpinned items are removed
- [ ] Settings → Maximum favorites defaults to 30 and can be changed
- [ ] The gallery shows an empty state when history is empty

## Keyboard, pointer, and card actions

- [ ] Left/Right changes selection and scrolls the selected card into view
- [ ] Back to Latest is hidden at the newest position and remains hidden through exactly 70pt of horizontal scrolling
- [ ] After scrolling more than 70pt, **Back to Latest** appears beside the app name as a quiet glass capsule without moving the centered toolbar
- [ ] Clicking Back to Latest selects the newest card, places it at the left edge, and hides the action again
- [ ] Back to Latest still repositions the gallery when the newest card was already selected before manual scrolling
- [ ] Back to Latest is hidden for empty results and is readable in all six skins, Light/Dark appearance, Reduce Transparency, and Increase Contrast
- [ ] Back to Latest fades/moves by 4pt in 160ms; Reduce Motion removes the movement
- [ ] VoiceOver announces Back to Latest, the Favorites filter state, Filters with active count, Content Type, all four localized choices, and every source app
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

## Workbench skins

- [ ] Settings shows six previews in this order: Default, Warm Paper, Moss Garden, Graphite, Mist Blue, Rose Ash.
- [ ] Selecting each preview updates the next opened workbench without restarting the app.
- [ ] The selected skin survives quit and relaunch.
- [ ] Search text, filters, and selected card survive a live skin change.
- [ ] Default still follows macOS Light and Dark appearances.
- [ ] Each custom skin keeps its approved identity after switching macOS appearance.
- [ ] Text, image, mixed, favorite-note, selected, and empty states remain readable in every skin.
- [ ] Reduce Transparency replaces glass with an opaque theme surface.
- [ ] Increase Contrast strengthens panel, control, and card outlines.
- [ ] Keyboard and VoiceOver can identify and choose every skin preview.

## Automated checks

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' clean build
```

Done when every applicable manual item passes, the test command reports `** TEST SUCCEEDED **` with zero failures, and the clean build reports `** BUILD SUCCEEDED **`.
