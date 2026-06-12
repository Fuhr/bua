# Handover — Bua (บัว)

**Context:** Bua is Søren's personal macOS menu-bar companion: a breathing lotus that mirrors the Claude Code session limit — full sage bloom at 0%, folding through jade → pink → coral into a twilight bud at 100%, re-blooming on reset. Session 1 (2026-06-12/13) built it from nothing to a finished v1: live data layer, SVG-faithful lotus on a tranquil pond, Søren's Wise Words quotes, global hotkey, all merged on `main` at `Fuhr/bua` (private). **Status: in daily use, no open build work.**

## Session 1 — 2026-06-12 → 13

### What Got Done

- Scaffolded the whole app (SwiftPM + Makefile, no Xcode project, ad-hoc signed, LSUIElement) and verified the data path live: Claude Code OAuth token from the login keychain → `api.anthropic.com/api/oauth/usage` → decoded percentages (probe + 12 offscreen renders).
- Lotus geometry, 4 design iterations against Søren's Noun Project SVG references: curved petal spines (quadratic from steep base tangent, wings dip below horizontal) + width profile peaked at 55% — reads as the classic Buddhist lotus icon at every closure stage.
- Panel: non-activating NSPanel (pin, click-away dismiss, remembers dragged position), light/dark + manual Appearance override, session bar (journey-tinted) above week bar, demo mode (⌥ scrub).
- Quotes: hand-converted Søren's entire `Wise Words/Wisewords.md` (~240 entries — deduped, URLs stripped, typos fixed, his voice kept) into fortune-format `quotes.txt`; ≤5-estimated-line entries rotate, click for another, attributions shown.
- Calm-under-failure pass: 429 keeps last-good silently, panel-open refreshes throttled to 45s, bloom survives 8 failed polls before resting (countdown needs no network).
- Outlined menu-bar glyph (filled version read as a cup at 18px).
- Global hotkey **⌃⌥B** (Carbon RegisterEventHotKey, zero permissions) + in-app Change Shortcut… recorder window.
- Tranquil pond (final design pass): water plane, mirrored reflection, two ripples drifting on the 7s breath, whisper-of-sky chrome gradient (warm morning / indigo night), glow dims as the session closes toward night. Copy now says "claude session · resets HH.MM".
- Repo `Fuhr/bua` created (private), 11 commits, `tranquil-pond` merged to main and branch deleted.

### Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Usage data source | Keychain token via `security` CLI + OAuth usage endpoint | Exact same numbers as `/usage`; the item's partition list lets the Apple-signed CLI read with **zero prompts** — `SecItemCopyMatching` would re-prompt after every ad-hoc rebuild |
| Token handling | **Never refresh** | Refresh tokens rotate; consuming one could invalidate Claude Code's credentials |
| Panel architecture | NSStatusItem + custom non-activating NSPanel | `MenuBarExtra(.window)` can't pin and gives no chrome control |
| Visual verification | `Bua --snapshot` offscreen ImageRenderer loop | screencapture/AppleScript are permission-blocked for the terminal; NSVisualEffectView can't render offscreen → `offscreenChrome` flag |
| Lotus construction | Curved spine + explicit width profile, few fat overlapping petals | Straight petals rotated around a point read as agave/starburst — took 4 iterations to learn |
| Quote storage | Fortune-format file in Application Support, local-only | Personal collection; `Wise Words/` git-ignored, nothing intimate leaves the machine |
| Failure posture | Keep-last-good; rest only after sustained failure | The reset time is a fixed timestamp — calm beats alarm |
| Multi-provider future | Label only ("claude session"), no abstraction | Build the seam (UsageModel/UsageFetcher) when a second provider actually arrives |

### Decisions Still Open

| Decision | Options | Blocker |
|---|---|---|
| The ~40 long-form quotes (Man in the Arena, Osho…) | Dedicated "longer reflection" view · click-to-expand · leave them resting | Waiting for Søren to want it |
| Codex/Mistral ponds | Multi-provider UI shape unknown | Hypothetical until a second garden knocks |

### Known Watch-outs

- The usage endpoint is **undocumented** — it can change or be restricted. Resting state is the designed failure mode; the Codable layer is deliberately lenient (all optionals).
- Keychain service name `Claude Code-credentials` has been renamed between Claude Code versions before — named constant in `KeychainReader.swift`.
- If "resting — the garden is out of reach" shows while Claude is clearly working **for >10 minutes**, that's not rate limiting — add a diagnostics item to the right-click menu and investigate.
- Breathing, ripples, and the hotkey can only be verified live — snapshots are stills, and the terminal can't press keys.
- The quote fit heuristic is ~36 chars/line ≤5 lines; if a quote ever truncates again, that constant is in `Quotes.fitsPanel`.

### What's Next

- **Unblocked:** daily use is the UAT. Water/ripple/breath/sky intensities are each a single constant if anything feels off.
- **Nice-to-haves (no urgency):** longer-reflection view for the big quotes; Launch-at-Login on by default; diagnostics menu item; glyph matching at small sizes.
- **Needs nobody.**

### Resume Instructions

1. `cd ~/Developer/bua && git pull && make run` — builds, signs, relaunches.
2. `make probe` — sanity-check the data layer (keychain + endpoint) in 5 seconds.
3. `.build/arm64-apple-macosx/release/Bua --snapshot` → `/tmp/bua-snapshots` — the design-review loop.
4. Quotes live at `~/Library/Application Support/Bua/quotes.txt` (right-click lotus → Edit Quotes…).
5. Session memory exists: `project_bua_lotus_menubar_app.md` in the benevolent-pm Claude memory.

Next-session starter prompt:

```
Bua session 2. Read ~/Developer/bua/handover-bua-2026-06-13.md first.
I've been living with the app — here's my feedback: …
```

### Files Changed

Entire repo created this session: `Package.swift`, `Makefile`, `README.md`, `.gitignore`, `Resources/Info.plist`, and `Sources/Bua/` — `main`, `StatusController`, `LotusPanel`, `PanelContentView`, `LotusView`, `ColorJourney`, `UsageModel`, `KeychainReader`, `Theme`, `Probe`, `Snapshot`, `Quotes`, `HotKey`, `ShortcutRecorder` (14 Swift files). Outside the repo: `~/Library/Application Support/Bua/quotes.txt` (converted Wise Words collection), Claude session memory file.

*Handover: 2026-06-13, end of session 1*
