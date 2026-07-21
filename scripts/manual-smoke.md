# clipai Phase 1 — Manual smoke checklist

Use after building and running clipai from Xcode. Tick each item when it behaves as described.

## Prerequisites

- [ ] Generated project: `./scripts/generate-project.sh`
- [ ] Built & run clipai (menu bar shows **clipai**)
- [ ] Optional: TextEdit or Notes open for paste targets

## Checklist (design DoD)

1. **Launch**
   - [ ] Status bar shows `clipai`
   - [ ] No Dock icon (accessory / `LSUIElement`)

2. **Text history**
   - [ ] Copy three different text snippets
   - [ ] Open history (status menu **Show History** or **⇧⌘V**)
   - [ ] All three appear in the list (newest first)

3. **Search + paste**
   - [ ] Type a search query that matches only one item
   - [ ] Select it → **Paste** into TextEdit
   - [ ] With Accessibility enabled: text appears without manually pressing ⌘V
   - [ ] Panel closes after paste

4. **Dedupe**
   - [ ] Copy the same text twice
   - [ ] History still shows one row for that content (updated time may change)

5. **Images**
   - [ ] Copy a screenshot or image
   - [ ] History shows an image row (🖼)
   - [ ] Paste into Preview / Notes succeeds

6. **Ignore rules**
   - [ ] Preferences → add current test app’s bundle ID (or a known ID)
   - [ ] Copy something from that app → it is **not** ingested
   - [ ] Remove ignore → copy again → ingested

7. **Accessibility degrade**
   - [ ] Turn off Accessibility for clipai (or never grant it)
   - [ ] **Paste** from history → content is copied; status guides to enable Accessibility / press ⌘V
   - [ ] Re-enable Accessibility → auto-paste works again

8. **Clear all**
   - [ ] Preferences → **Clear All History…**
   - [ ] History list is empty

9. **Persistence**
   - [ ] Copy a few items (do not clear)
   - [ ] Quit clipai and relaunch
   - [ ] History still present under `~/Library/Application Support/clipai/`

10. **Capacity prune**
    - [ ] Preferences → set max items low (e.g. 50)
    - [ ] Ingest more than the limit
    - [ ] Oldest items are pruned

## Extras

- [ ] **Copy** button places item on pasteboard without auto-paste
- [ ] **Delete** removes a single row
- [ ] **Launch at login** toggle does not crash (may need a signed build for full SMAppService effect)
- [ ] Quit via menu ends the process cleanly

## Done when

All checklist items pass on a local Mac with full Xcode. Unit tests:

```bash
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' test
```
