# clipai Design Spec

**Date:** 2026-07-20  
**Status:** Draft for user review (brainstorming approved in conversation)  
**Project path:** `/Users/wangqd/restart/clipai`  
**Stack:** Swift, native macOS, single-process modular menu-bar app (Approach A)

---

## 1. Positioning and Goals

### 1.1 Product positioning

**clipai** is a macOS **menu-bar clipboard history tool**. It records what you copy in the background, lets you find it again with a hotkey, and paste it back—so “copy → overwrite → can’t find it” stops happening.

| Dimension | Definition |
|-----------|------------|
| What it is | A **local history extension** for the system clipboard (Paste-class core capability) |
| What it is not | Not a screenshot tool (Snipaste), not a password manager, **not an AI product in Phase 1** |
| Who | **Personal daily use** first (dev/office: browser, terminal, IM, IDE) |
| Where | macOS only; menu-bar resident (`LSUIElement`-style), does not live in the Dock as a normal app |
| Stack | **Native Swift**, single-process modular architecture (Approach A) |
| Data | **Local by default**; no iCloud / accounts / cloud sync in Phase 1 |
| “AI” in the name | Brand reserve; **capability deferred**—must not block the clipboard loop |

One-liner:

> **clipai Phase 1 = reliable local clipboard history. AI is future value-add, not the main line now.**

### 1.2 Phase 1 goals (success looks like)

You can **rely on it every day**, not open it as a toy:

1. After copying text or images, items land in history reliably (sensible dedupe, no obvious drops).
2. Hotkey opens the panel; search/select pastes into the current app (or degrades cleanly).
3. Menu-bar resident, optional launch-at-login, low annoyance.
4. Password-class apps can be ignored to avoid obvious foot-guns.
5. After a week of use, you still want to keep it (stable, fast, light).

### 1.3 Phase 1 non-goals

- AI summarize / translate / semantic search / agents  
- iCloud sync, multi-device  
- Full support for file/folder copy history  
- Multi-pinboard, complex rule engine  
- Mac App Store listing and monetization  
- Windows / cross-platform  

### 1.4 Phase 2 direction (not implementation detail)

After Phase 1 is stable for daily use:

- File types, stronger plain-text paste, Direct Paste compatibility  
- Pin / pinboard, finer rules and retention  
- UX polish (Quick Look, sound, multi-display)  
- Optional **AI layer** later (local HTTP client is enough)

### 1.5 Design principles

1. **Local-first, privacy by default** — clipboard content is not uploaded in Phase 1  
2. **Close the loop before features** — monitor → store → find → paste must work before the next layer  
3. **Light resident process** — control memory and wake frequency  
4. **Clear module boundaries** — Monitor / Store / Panel / Paste are independently understandable and testable  
5. **YAGNI** — no complex sync/plugin system in Phase 1; only directory-level extension points  

---

## 2. Naming Convention (locked)

**Technical and product identifiers use `clipai` only.** Do not maintain a second spelling family (`AIClip` / `aiclip` as alternate product paths).

| Use | Value |
|-----|--------|
| Product / spoken name | **clipai** |
| Project directory | `/Users/wangqd/restart/clipai` |
| Bundle ID | `com.eden.clipai` |
| Preferences domain / queue labels | `com.eden.clipai` |
| Application Support | `~/Library/Application Support/clipai/` |
| Database file | `clipai.sqlite` |
| Media directory | `~/Library/Application Support/clipai/media/` |
| Xcode project / target | `clipai` |
| URL scheme (if ever) | `clipai://` |

Swift type names may use legal identifiers such as `ClipAIApp` where required by language rules; **user-facing strings, paths, and bundle IDs stay `clipai` / `com.eden.clipai`.**

---

## 3. Features and Phase Boundaries

### 3.1 Capability map

| Capability | Description | Phase 1 | Phase 2 |
|------------|-------------|---------|---------|
| Clipboard monitoring | Detect `changeCount` changes and ingest | Yes | — |
| Text history | Plain text; rich text → searchable plain extraction | Yes | Higher fidelity |
| Image history | Common types (PNG/TIFF etc.), thumbnail + file on disk | Yes | Large-image policy |
| Dedupe | Same content refreshes timestamp, no spam rows | Yes | Configurable |
| History UI | Menu bar / hotkey panel with cards/list | Yes | Animation / multi-display |
| Search | Keyword on preview/body (`LIKE` or FTS later) | Yes | Semantic (AI) later |
| Paste | Write pasteboard + simulate ⌘V (Accessibility) | Yes | Stronger Direct Paste |
| Paste as plain text | Strip RTF/HTML | Optional light | Full |
| Copy only | Write pasteboard without ⌘V | Yes | — |
| Delete one / clear all | History management | Yes | — |
| Source app | bundleId + name when available | Yes | Icon cache |
| Ignore apps | bundleId denylist | Basic | Richer UI |
| Secret heuristics | Simple password heuristics | Optional light | Yes |
| Retention | Max count (or days) + prune | Simple | Finer policy |
| Launch at login | Login Item / SMAppService | Yes | — |
| Menu bar icon | Show/hide preference | Yes | — |
| Global hotkey | Open panel (default suggest ⇧⌘V) | Yes | More shortcuts |
| Preferences | Capacity, ignore list, hotkey, launch | Basic | Full settings |
| File copy history | File URLs / multi-file | No | Yes |
| Pin / pinboard | Pin favorites, multiple lists | No | Yes |
| Quick Look | Space preview | No | Yes |
| iCloud sync | Multi-device | No | Later |
| AI | Summarize / translate / semantic search | No | Optional later |
| Sound / themes | Polish | No | Optional |

### 3.2 Phase 1 must-ship (MVP)

**Loop: monitor → store text/image → open panel → search/select → paste**

1. **ClipboardMonitor** — poll `NSPasteboard.general.changeCount` (~0.3s constant); ignore self-write loops  
2. **Ingester** — priority image then text; content hash dedupe; best-effort `sourceApp`  
3. **Store** — SQLite metadata; images under `Application Support/clipai/media/`; default capacity e.g. max **500** items; prune oldest by `updatedAt`  
4. **HistoryPanel** — global hotkey; list with text preview / thumbnail, time, source; keys: up/down, Enter paste, Esc close, type to search  
5. **PasteEngine** — write pasteboard + ⌘V if Accessibility trusted; else copy-only + prompt; support copy-only mode  
6. **Rules** — ignore bundleId list (preset Keychain / 1Password / Bitwarden + user adds)  
7. **App shell** — menu bar: history / preferences / quit; launch-at-login; basic prefs  

### 3.3 Phase 1 acceptance checklist

- [ ] Multiple text copies are findable and pastable into Notes/IDE  
- [ ] Screenshot or browser image previews and pastes  
- [ ] Duplicate copies do not flood the list  
- [ ] Ignored apps do not ingest  
- [ ] Without Accessibility: no crash; clear guidance; content still on pasteboard  
- [ ] History survives app restart  

### 3.4 Phase 2 priority order (guidance)

| Order | Capability | Value |
|-------|------------|--------|
| P2.1 | Pin + single pinboard | Keep favorites |
| P2.2 | Plain-text paste + more hotkeys | High for developers |
| P2.3 | File types + better preview / Quick Look | Closer to Paste |
| P2.4 | Stronger ignore/secret rules, retention UI | Privacy and hygiene |
| P2.5 | Direct Paste compatibility, multi-display, sound | Polish |
| P2.6 | Optional AI: clean / translate / summarize / semantic search | Brand fulfillment |
| Later | iCloud, notarized distribution | Productization |

Phase 2 still: **local default; AI optional and off-switchable.**

---

## 4. Architecture and Module Structure

### 4.1 Approach

**Approach A — Menu-bar app + modular single process** (chosen).

Absorb Approach C’s layering idea **inside one app target** (clear folders, not mandatory multi-package SPM for Phase 1).

```text
┌──────────────────────────────────────────────────────────┐
│                     App shell (clipai)                     │
│  Lifecycle · menu bar · hotkeys · prefs · permission UX   │
└────────────┬─────────────┬───────────────┬───────────────┘
             │             │               │
             ▼             ▼               ▼
      ┌────────────┐ ┌───────────┐  ┌─────────────┐
      │  Monitor   │ │  Panel    │  │ Preferences │
      └─────┬──────┘ └─────┬─────┘  └──────┬──────┘
            ▼              │               │
      ┌────────────┐       │               │
      │  Ingester  │       │               │
      └─────┬──────┘       │               │
            ▼              ▼               ▼
      ┌─────────────────────────────────────────┐
      │         Store (only persistence API)     │
      │   SQLite + media files + query/prune     │
      └────────────────────┬────────────────────┘
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
      ┌──────────┐  ┌──────────┐  ┌────────────┐
      │  Rules   │  │  Paste   │  │  (Phase 2  │
      │          │  │ Engine   │  │   AI: n/a) │
      └──────────┘  └──────────┘  └────────────┘
```

**Dependency rules (one-way):**

- UI → Store / Paste / Rules  
- Monitor → Ingester → Store (writes)  
- Ingester → Rules (should ingest?)  
- **Store does not depend on UI**  
- **Monitor does not depend on Panel**  

### 4.2 Repository layout (planned for implementation)

```text
/Users/wangqd/restart/clipai/
├── README.md
├── docs/superpowers/
│   ├── specs/2026-07-20-clipai-design.md
│   └── plans/                          # implementation plans after approval
├── clipai/                             # Xcode project root (created at implementation)
│   ├── clipai.xcodeproj
│   ├── clipai/
│   │   ├── App/
│   │   │   ├── ClipAIApp.swift         # @main (Swift type name)
│   │   │   ├── AppState.swift
│   │   │   ├── MenuBarController.swift
│   │   │   └── HotKeyManager.swift
│   │   ├── Clipboard/
│   │   │   ├── ClipboardMonitor.swift
│   │   │   ├── PasteboardIngester.swift
│   │   │   ├── PasteboardReader.swift
│   │   │   └── ContentHasher.swift
│   │   ├── Storage/
│   │   │   ├── Models.swift
│   │   │   ├── SnippetStore.swift
│   │   │   ├── Database.swift
│   │   │   └── MediaStore.swift
│   │   ├── Paste/
│   │   │   ├── PasteEngine.swift
│   │   │   └── PasteboardWriter.swift
│   │   ├── Rules/
│   │   │   ├── IgnoreRuleStore.swift
│   │   │   └── DefaultIgnoreList.swift
│   │   ├── UI/
│   │   │   ├── History/
│   │   │   └── Preferences/
│   │   └── Resources/
│   └── clipaiTests/
└── scripts/                            # optional
```

No Phase 1 `AI/` implementation directory required.

### 4.3 Module responsibilities

| Module | Does | Does not |
|--------|------|----------|
| App shell | Launch, wire services, menu bar, hotkeys, permission prompts | Parse pasteboard details |
| ClipboardMonitor | Detect pasteboard changes | Parse, write DB |
| PasteboardReader | Extract text/image payloads from `NSPasteboard` | Policy / UI |
| PasteboardIngester | Apply rules, hash, upsert | Display |
| ContentHasher | Stable hashes | I/O |
| SnippetStore | CRUD, search, capacity; sole persistence API | Read system pasteboard |
| MediaStore | Image file read/write/delete | SQL |
| Rules | Ignore by bundleId | Store snippets |
| PasteEngine | Write pasteboard, ⌘V, degrade | Query history |
| History UI | List, search, select, paste/copy/delete actions | Direct SQL |
| Preferences UI | Hotkey, capacity, ignore list, launch at login | Monitor loop |

### 4.4 Logical APIs

```text
ClipboardMonitor
  start() / stop()
  → Ingester.handlePasteboardChange()

PasteboardIngester
  handlePasteboardChange()

SnippetStore
  upsert(_:)
  list(query:limit:) → [Snippet]
  delete(id:) / deleteAll()
  enforceCapacity()

PasteEngine
  paste(snippet, mode: .paste | .copyOnly)

IgnoreRuleStore
  isIgnored(bundleId:) → Bool
  add / remove / list
```

### 4.5 Phase 2 extension points

| Capability | Mount point |
|------------|-------------|
| Files | Reader branch + `kind: file` |
| Pin / pinboard | Store columns + UI tabs |
| Plain-text paste | `PasteEngine` mode |
| AI | Separate service; **read-only on selected snippet; never on monitor hot path** |

### 4.6 Environment constraint

- Full **Xcode** is required to produce a runnable `.app` (Command Line Tools alone are insufficient for this UI app).  
- Document this in README at implementation time.

---

## 5. Data Model and Main Flows

### 5.1 On-disk layout

```text
~/Library/Application Support/clipai/
├── db/
│   └── clipai.sqlite
└── media/
    └── {snippetId}.<ext>
```

- Preferences (hotkey, capacity, launch at login, etc.) → `UserDefaults` suite `com.eden.clipai`  
- Ignore list → Phase 1 `UserDefaults` string array (migrate to SQLite in Phase 2 if needed)

### 5.2 Domain model

**SnippetKind:** `text` | `image`  
(Phase 2+: `file`, `rtf`, `url`, `unknown`)

**Snippet fields:**

| Field | Type | Notes |
|-------|------|--------|
| id | UUID string | PK |
| createdAt | Date | First insert |
| updatedAt | Date | Refreshed on dedupe hit; default list sort |
| kind | enum | text / image |
| contentHash | string | Dedupe key; unique per kind |
| previewText | string | List/search; image may be empty or `Image (w×h)` |
| textBody | string? | text only; full body in DB for Phase 1 |
| mediaPath | string? | Relative under `media/`; image only |
| byteSize | Int | UTF-8 bytes or image file size |
| sourceBundleId | string? | Best-effort frontmost |
| sourceAppName | string? | Display |

**Limits (Phase 1 defaults; constants in implementation plan):**

- Text: truncate around **200KB** with preview marker if needed  
- Image: skip if over **~20MB** (log; do not crash)  
- Hash:  
  - text: `sha256("text:" + utf8)`  
  - image: `sha256("image:" + rawBytes)` (pick one normalization and stick to it)

**Capacity:** `maxSnippetCount` default **500**; `enforceCapacity()` deletes oldest by `updatedAt`, and deletes media files for images.

### 5.3 SQLite schema (Phase 1)

```sql
CREATE TABLE snippets (
  id            TEXT PRIMARY KEY,
  created_at    REAL NOT NULL,
  updated_at    REAL NOT NULL,
  kind          TEXT NOT NULL,
  content_hash  TEXT NOT NULL,
  preview_text  TEXT NOT NULL DEFAULT '',
  text_body     TEXT,
  media_path    TEXT,
  byte_size     INTEGER NOT NULL DEFAULT 0,
  source_bundle_id TEXT,
  source_app_name  TEXT
);

CREATE UNIQUE INDEX idx_snippets_kind_hash
  ON snippets(kind, content_hash);

CREATE INDEX idx_snippets_updated
  ON snippets(updated_at DESC);
```

Search Phase 1: `LIKE` on `preview_text` / `text_body`. Phase 2 may add FTS5.

### 5.4 Main flows

**Ingest**

```text
changeCount != last
  → if internal write: ignore (loop guard)
  → Reader: image else string else return
  → if Rules.isIgnored(frontmost): return
  → hash → Store.upsert (update updatedAt if exists else insert + media)
  → enforceCapacity()
  → refresh panel if visible
```

**Loop guard:** PasteEngine sets internal-write flag (or generation token) before writing pasteboard; Monitor ignores matching self-induced changes.

**List / search**

```text
Store.list(query, limit: 100)
  empty query → ORDER BY updated_at DESC
  non-empty → LIKE on preview_text OR text_body
```

**Paste**

```text
Enter → hide panel → write pasteboard → ⌘V if trusted else copy-only + guide
```

**Delete / clear:** row + media file; clear all empties table + media dir.

**Launch:** open Store → load Rules → start Monitor → register hotkey → menu bar ready.

### 5.5 Concurrency

| Concern | Convention |
|---------|------------|
| Monitor | Main-thread timer or serial queue for read→ingest |
| Store | Single-writer serial queue `com.eden.clipai.store` |
| UI | Main thread; refresh via notification / stream / `@Published` |
| Thumbnails | Decode off main; placeholder on failure |

### 5.6 Error handling (Phase 1)

| Scenario | Behavior |
|----------|----------|
| DB open fails | Menu-bar error; do not start Monitor |
| Image too large | Skip item |
| Text too large | Truncate and store |
| Accessibility off | Copy-only + settings guide |
| Missing media file | Broken placeholder; allow delete |

---

## 6. Permissions, Privacy, Risks, Acceptance

### 6.1 Permissions

| Permission | Phase 1 | Purpose | If denied |
|------------|---------|---------|-----------|
| Accessibility | Recommended | Simulate ⌘V | Copy-only + open System Settings guide |
| Automation | No | — | — |
| Full Disk Access | No | — | — |
| Network | No in Phase 1 | — | No cloud |
| Login item | Optional | Launch at login | Feature off |
| App Sandbox | Optional for personal build | Easier pasteboard/events | Revisit for MAS later |

### 6.2 Privacy

1. History only under `~/Library/Application Support/clipai/`  
2. **Phase 1: no upload** — no account, no analytics SDK, no cloud crash reporter unless later with explicit opt-in  
3. Default ignore list includes password managers / Keychain-class apps  
4. Provide clear history; document data directory for manual wipe  
5. Product statement: **clipai Phase 1 does not send clipboard contents to any server.**

### 6.3 Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Secrets in history | Ignore list; Phase 2 heuristics |
| ⌘V into wrong app | Hide panel first; focus policy in implementation plan |
| Self-write loop | Internal write guard + hash skip |
| Disk fill from images | Per-image cap + max count |
| Timer battery | ~0.3s poll; later idle backoff |
| No full Xcode | Blocker called out; install before UI work |
| Scope creep (AI/sync) | Non-goals locked in this spec |

### 6.4 Phase 1 Definition of Done

**Functional**

- [ ] Text history persists across restart and is searchable  
- [ ] Images show thumbnails and paste  
- [ ] Dedupe works  
- [ ] Ignore list works  
- [ ] Hotkey panel + Enter paste / Accessibility degrade  
- [ ] Delete one and clear all (media cleaned)  
- [ ] Capacity prune works  
- [ ] Menu bar: prefs + quit  

**Quality**

- [ ] 50 rapid copies without crash  
- [ ] Self-paste does not spam history  
- [ ] Unit tests for hash, dedupe, capacity, ignore  

**Docs**

- [ ] This design spec approved  
- [ ] README: purpose, build, permissions, data path  
- [ ] Naming consistent with section 2  

**Out of Phase 1 DoD:** files, pinboard, iCloud, AI, MAS.

---

## 7. Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Approach A: modular menu-bar single process | Closest to Paste; clear Phase 1/2 seams; not over-engineered |
| Language | Swift native | System clipboard, Accessibility, light resident app |
| Phase 1 scope | Personal daily use; text + images only | Fast habit formation; avoid Paste-complete scope |
| AI | Deferred entirely in Phase 1 | Name is reserve; clipboard loop first |
| Bundle ID | `com.eden.clipai` | Owner decision |
| Naming | All `clipai` / `com.eden.clipai` | Remove AIClip/clipai dual branding confusion |
| Persistence | SQLite + media files | Simple, testable, enough for history scale |
| Paste strategy | Write + ⌘V with Accessibility; degrade to copy-only | Usable without permission; better with it |
| Sync | None in Phase 1 | Privacy and scope |
| Packaging | Non-sandboxed personal app first | Fewer blockers; revisit for distribution |

---

## 8. Open Questions

Resolved in brainstorming:

- Phase 1 bar → **personal daily use**  
- Content types → **text + images**  
- Architecture → **Approach A**  
- Bundle ID → **com.eden.clipai**  
- Product naming → **clipai**  

Remaining (can default at implementation plan time if user does not care):

1. Default hotkey: **⇧⌘V** vs other (must not fight system/Paste if both installed)  
2. Default `maxSnippetCount`: **500** vs other  
3. UI toolkit mix: SwiftUI panel + AppKit panel hosting vs mostly AppKit  

Suggested defaults if unspecified: ⇧⌘V, 500, SwiftUI views hosted in `NSPanel`.

---

## 9. PR Plan (implementation sequencing)

Incremental, each step reviewable. **No code until implementation plan is written and user starts execution.**

| PR | Title | Scope | Depends on |
|----|-------|--------|------------|
| PR1 | chore: repo skeleton + naming + README stub | git layout, `.gitignore`, docs already present, Xcode project shell `com.eden.clipai` | — |
| PR2 | feat: storage models + SQLite + media | `Models`, `Database`, `MediaStore`, `SnippetStore`, capacity, tests | PR1 |
| PR3 | feat: hasher + ignore rules + ingester (no UI) | `ContentHasher`, `IgnoreRuleStore`, `PasteboardReader`/`Ingester`, unit tests | PR2 |
| PR4 | feat: clipboard monitor + loop guard | `ClipboardMonitor`, internal-write coordination with writer stub | PR3 |
| PR5 | feat: paste engine | `PasteboardWriter`, `PasteEngine`, Accessibility degrade path | PR4 |
| PR6 | feat: menu bar shell + hotkey + history panel | App shell, hotkey, SwiftUI/AppKit panel, list/search/delete | PR5 |
| PR7 | feat: preferences + launch at login + polish | Capacity, ignore editor, launch, permission UX copy | PR6 |
| PR8 | docs: README complete + manual test script | Build steps, permissions, data dir, Phase 1 DoD checklist | PR7 |

Phase 2 work is **out of this PR plan** (separate specs later: pin, files, AI).

---

## 10. Out of Scope Recap

- Implementation code in this document  
- AI features, cloud sync, file snippets, pinboards  
- App Store submission  
- Cross-platform  

---

## Document history

| Date | Change |
|------|--------|
| 2026-07-20 | Initial design from superpowers brainstorming; Approach A; Phase 1 text+image daily driver; naming locked to clipai; bundle `com.eden.clipai` |
