# clipai

Local macOS clipboard history (Phase 1). Bundle ID: `com.eden.clipai`.

## Requirements

- macOS 13+
- Full Xcode (not only Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Generate & run

```bash
./scripts/generate-project.sh
open clipai.xcodeproj
# Product → Run (⌘R)
```

## Data

`~/Library/Application Support/clipai/`

## Docs

- Spec: `docs/superpowers/specs/2026-07-20-clipai-design.md`
- Plan: `docs/superpowers/plans/2026-07-21-clipai-phase1.md`

Phase 1 does **not** upload clipboard contents.
