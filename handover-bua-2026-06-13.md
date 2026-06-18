# Handover — Bua (บัว)

**Context:** Bua is Søren's personal macOS menu-bar companion: a breathing lotus that mirrors the Claude Code session limit — full sage bloom at 0%, folding through jade → pink → coral into a twilight bud at 100%, re-blooming on reset. Session 1 (2026-06-12/13) built it from nothing to a finished v1: live data layer, SVG-faithful lotus on a tranquil pond, Søren's Wise Words quotes, global hotkey, all merged on `main` at `Fuhr/bua` (private). Session 2 (2026-06-13) added the daily-use polish: visible weekly-reset time, menu-only demo, an eased "linger then fold" bloom curve, and an app icon. Session 3 (2026-06-18) made Bua **shareable** — a `make dist`
zip, an animated welcome/landing page that doubles as the install guide, a README
refresh, a starter-quotes expansion (8 → 30), and parked the public-release
decisions. **Status: in daily use; all committed + pushed (`origin/main` =
`f50909a`). Open: the sleep-on-it public-release decisions in `notes/distribution.md`.**

## Session 3 — 2026-06-18

**Context:** Started from "how do I share Bua with a friend?" → built the whole
sharing path. (A parallel thread — sharing with a *second* friend who uses Codex,
not Claude — is parked in `CODEX-SUPPORT.md`.)

### What Got Done

- **Shareable install tooling.** New `make dist` → `build/Bua-install.zip` (ad-hoc
  `Bua.app` + a welcome page), and `make install` → updates the `/Applications`
  copy in one step (fixes the diverging-copies pain Session 2 flagged).
- **Animated welcome/landing page** (`site/index.html`). Concept: *scroll through a
  day* — the sky travels dawn → indigo-night and the lotus folds from full bloom →
  twilight bud as you scroll, so you reach "how to install" having felt *not
  failure, nightfall*. Geometry + colour ported faithfully from `LotusView.swift` /
  `ColorJourney.swift`; the live lotus colours use the app's **exact OKLCH→sRGB
  matrix** (ported to JS, emits `rgb()`) so it renders on any browser. Self-contained,
  offline-safe (no web fonts/CDN), `prefers-reduced-motion` + dark-aware-ish,
  accessible. Verified headless via Playwright (no JS errors; renders across
  scroll / theme / reduced-motion).
- **Ships in the zip** as `Welcome to Bua.html`; **`INSTALL.txt` retired** (the page
  is now the single source of truth for the install guide).
- **README** rewritten to match the site's voice + document the new make targets.
- **Starter quotes 8 → 30** (`Quotes.swift`) — public-safe set only (famous /
  proverbial + Bua's own voice); personal quotes stay in the local `quotes.txt`.
- **Pushed Session-2's unpushed commits** + the Session-2 handover narrative (both
  had been left local).
- **Parked Codex (OpenAI) provider support** (`CODEX-SUPPORT.md`) and the
  **public-release reflections** (`notes/distribution.md`, gitignored).

### Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Landing-page concept | Scroll = the lotus's day (dawn→night), lotus folds toward the install | Makes the app's metaphor the page's spine; faithful, surprising |
| Live colour rendering | Port the app's exact OKLCH→sRGB matrix to JS, emit `rgb()` | Renders identically on any browser, not just oklch-aware ones |
| System dark mode | Page does **not** follow it | The dawn→night light journey *is* the concept; system-dark would fight it |
| Install guide delivery | HTML page in the zip; retire `INSTALL.txt` | One source of truth; a friend opens beauty, not a txt file |
| Distribution posture | Free + open-source (MIT) brand piece, **not** a paid product | Thin utility on an undocumented endpoint; value = goodwill/trust for benevolent.pm |
| `notes/distribution.md` | Gitignored | Internal musings must never enter a (future public) repo's history |
| Quotes in source | Public/famous attributions only | Privacy — friend release is fine, but scrub before any public release |

### Decisions Still Open (sleep-on-it — in `notes/distribution.md`)

| Decision | Options | Blocker |
|---|---|---|
| Make `Fuhr/bua` public? | Yes (recommended) / no | Søren's call |
| Notarize for a clean public download? | Pay $99 Apple Dev + notarize / stay ad-hoc + teach the unblock | $99 + enrollment |
| Licence | MIT (recommended) / other | — |
| Tip jar | None / Ko-fi / GitHub Sponsors | — |
| `benevolent.company/bua` page + download | Host `site/` + link a GitHub Release | that site's stack |
| Pre-public scrub pass (quotes + personal refs) | — | gated on the public decision |

### Known Watch-outs

- The zip's `.app` is **ad-hoc signed** → on Sequoia the friend must do
  System Settings → Privacy & Security → **Open Anyway** (the page covers it, plus an
  `xattr -dr com.apple.quarantine` one-liner). A *public* download really wants
  notarization, or it looks sketchy.
- **`notes/distribution.md` is gitignored** — it won't appear in `git status` or on
  GitHub. Don't expect it in the repo.
- The page **deliberately ignores system dark mode** (it's its own dawn→night world).
  A system-dark variant would be new work.
- **Personal-quote rule:** never put personal / "said only to me" quotes into
  `Quotes.swift`'s `starter` — they ship in the binary and would go public. Personal
  quotes live only in the local `quotes.txt`.
- Playwright verification ran from **benevolent-pm's** `node_modules` (bua has no
  node) via `NODE_PATH`. The `/tmp/bua-*.png` screenshots + `/tmp/bua-verify.cjs` are
  throwaway — regenerate if gone.
- Codex support is **blocked** on capturing what `codex` `/status` requests against
  `chatgpt.com/backend-api/` — needs a Codex account/machine (see `CODEX-SUPPORT.md`).

### What's Next

- **Unblocked now:** AirDrop `build/Bua-install.zip` to the Claude-Code friend.
- **Needs Søren:** the sleep-on-it decisions above.
- **If going public:** pre-flight git-history scan → add MIT `LICENSE` + a "personal
  toy, no support" note → scrub pass → make repo public → optional `make notarize` →
  cut a GitHub Release → host `site/` at `benevolent.company/bua`.
- **Optional:** prune any of the 22 added quotes; a system-dark page variant; the
  long-form-quote reflection view (pre-existing nice-to-have).
- **Later:** Codex provider support when an account is available.

### Resume Instructions

1. `cd ~/Developer/bua && git pull` (origin/main = `f50909a`).
2. Send it: `make dist` → AirDrop `build/Bua-install.zip` (app + `Welcome to Bua.html`).
3. Update your own copy: `make install`.
4. Read `notes/distribution.md` (local, gitignored) for the public-release decisions.
5. Preview the page: `open site/index.html`.
6. Re-verify headless: `NODE_PATH=~/Developer/benevolent-pm/node_modules node /tmp/bua-verify.cjs` (regenerate the script if it's gone).

### Files Changed

- **New:** `site/index.html`, `CODEX-SUPPORT.md`, `notes/distribution.md` (gitignored).
- **Modified:** `Makefile` (+`dist`, +`install`), `README.md`, `.gitignore` (+`notes/`),
  `Sources/Bua/Quotes.swift` (8→30 starters), `handover-bua-2026-06-13.md` (this entry).
- **Deleted:** `INSTALL.txt` (folded into the welcome page).

*Handover: 2026-06-18, end of session 3*

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

## Session 2 — 2026-06-13

Living-with-it feedback → four changes, all merged to `main` (commits `e5345ab`, `bd61aad`).

### What Got Done

- **Weekly-limit reset time in the panel.** Was hover-tooltip-only; now a caption under the bars ("weekly limit resets Sat 06:59"). `weeklyResetsAt` exposed on `UsageModel`; bars slot grew 38→54 and the panel 370→388 to fit without clipping (verified against the resting + longest-quote fixture).
- **Demo mode is menu-only.** Removed the ⌥ flags-monitor toggle from `StatusController` (`handleFlags`/`optionWasDown` + both flags monitors gone). Root cause: the show/hide hotkey is **⌃⌥B**, so its option press was firing the panel's demo toggle every time — show/hide kept flipping demo on. Right-click → Demo Mode still works; slider caption updated.
- **Eased "linger then fold" bloom.** New `visualClosure = pow(sessionUtilization, bloomEase)` (`bloomEase = 2.2`) drives the petals, the menu-bar glyph, and the session-bar tint. The flower stays open/green through ~the first half, then folds fast pink→coral→twilight in the back third. The % bars and countdown stay truthful (raw `sessionUtilization`).
- **App icon.** New `Icon.swift` renders the full-bloom lotus — green outer petals cradling a pink inner bloom — on a soft light rounded tile, reusing the panel/glyph petal geometry. `Bua --icon [path]` renders a 1024 master; `make icon` re-slices it into `Resources/AppIcon.icns`. Wired via `CFBundleIconFile` + a build-step copy into `Contents/Resources/`.

### Install Change

- Bua now also lives at **`/Applications/Bua.app`** (Spotlight/Launchpad-openable; it's `LSUIElement` so no Dock icon). `make run` still builds+opens `build/Bua.app`. **The two copies diverge** — `/Applications` is the daily app; to update it: `make build && rm -rf /Applications/Bua.app && cp -R build/Bua.app /Applications/`. (Consider folding an `install` target into the Makefile next session.)

### Tuning Knobs

| Knob | File | Default | Effect |
|---|---|---|---|
| `bloomEase` | `UsageModel.swift` | 2.2 | higher = flower lingers open longer before folding |
| lotus scale `0.70` | `Icon.swift` | 0.70 | icon boldness (fraction of tile the lotus fills) |

### Known Watch-outs (new)

- **Cold start × rate limit.** The undocumented usage endpoint 429s on back-to-back calls. With no cached data, a fresh launch then sits at "listening for the garden" until the 60s poll loop lands a 200 — it self-heals, just stop poking it. **Don't `--probe` right after `make run`** (that double-hit caused a scare this session).
- **Icon cache.** After changing the icon: `lsregister -f /Applications/Bua.app && killall Dock` to refresh Finder/Spotlight (full refresh may wait for next login).

### What's Next

- **Push** session-2 commits to `origin/main` (not done yet — Søren said "commit", push not requested).
- Nice-to-haves unchanged: longer-reflection view for the big quotes, Launch-at-Login on by default, diagnostics menu item, a Makefile `install` target.

### Resume (delta from session 1)

- `make icon` regenerates the icon after editing `Icon.swift`; `Bua --icon /tmp/x.png` for a quick master render.

*Handover: 2026-06-13, end of session 2*
