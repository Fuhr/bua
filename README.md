# Bua — บัว

*A tiny lotus in your menu bar that breathes with your Claude Code session.*

At the start of a session the lotus is a full open bloom in Benevolent sage green.
As you work, the petals gather into a bud and the colour travels through the day —
jade, lotus pink, sunset coral — until, at the limit, it rests as a closed bud in
twilight purple. **Not failure: nightfall.** When the session resets, it blooms again.

It is deliberately not feature-rich. A small, kind thing — *a benevolent little thing.*

## Use

| Gesture | What it does |
|---|---|
| **⌃⌥B** (anywhere) | Show / hide the panel — no cursor needed. Rebind via right-click → Change Shortcut… |
| Click the menu bar lotus | Show / hide the panel |
| Pin button (or right-click → Pin) | Keep the panel floating over everything |
| Drag the panel | It remembers the spot and reopens there |
| ⌥ while the panel is open | Demo mode — scrub through the whole day |
| Click the quote | Another quote |
| Right-click the menu bar lotus | Refresh, pin, demo, appearance, quotes, launch at login, quit |

The panel shows the session countdown, a session limit bar (tinted with the lotus's
current colour), the weekly limit bar (hover for the per-model breakdown), and a quote.

The hotkey needs no accessibility permission (Carbon `RegisterEventHotKey`). Rebind it
via right-click → Change Shortcut… (press the new chord; esc cancels, ⌫ resets to ⌃⌥B).

## Quotes

`~/Library/Application Support/Bua/quotes.txt` — entries separated by lines containing
only `%`; the final lines starting with `— ` are the attribution (optional); `#` lines
are comments. A random entry shows each time the panel opens. Entries longer than ~220
characters stay in the file but don't rotate into the panel. Open it via right-click →
Edit Quotes…

## Build

```sh
make run        # build, bundle, ad-hoc sign, launch
make install    # update the copy in /Applications
make probe      # print live usage to the terminal, no UI
make icon       # regenerate the app icon from Icon.swift
Bua --snapshot  # render the panel offscreen to /tmp/bua-snapshots (design review)
```

Requires Xcode command line tools. The app bundle lands in `build/Bua.app`.

## Share it with a friend

Bua is ad-hoc signed, not notarized — a personal thing passed between friends, not an
App Store app.

```sh
make dist       # → build/Bua-install.zip  (Bua.app + a welcome page)
```

AirDrop the zip. Your friend opens **Welcome to Bua.html** — a little landing page
(`site/index.html`) that lives the lotus's day from dawn to nightfall, says what Bua is,
and walks them through the one-time macOS unblock. They need an Apple Silicon Mac on
macOS 15+ with Claude Code logged in. (`site/` is also the seed of a future public page.)

## Privacy

Bua reads Claude Code's OAuth token from your login keychain (via the `security` CLI,
read-only) and sends it to exactly one place: `api.anthropic.com/api/oauth/usage` — the
same endpoint Claude Code's own `/usage` screen uses. It never refreshes, stores, or logs
the token, and it never sees your conversations. The quotes collection is local-only and
git-ignored. If anything fails, the lotus simply rests.
