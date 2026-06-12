# Bua — บัว

A tiny lotus in the menu bar that breathes with your Claude Code session.

At the start of a session the lotus is a full open bloom in Benevolent sage green.
As you use Claude, the petals slowly fold inward and the color travels through the
day — jade, lotus pink, sunset coral — until at the limit it is a closed bud in
twilight purple. Not failure: nightfall. When the session resets, it blooms again.

## Use

| Gesture | What it does |
|---|---|
| Click the menu bar lotus | Show / hide the panel |
| Leaf button (or right-click → Pin) | Pin the panel so it floats over everything |
| ⌥ while the panel is open | Demo mode — scrub through the whole day |
| Right-click the menu bar lotus | Refresh, pin, demo, launch at login, quit |

The thin bar under the countdown is the weekly limit; hover it for the
per-model breakdown.

## Build

```sh
make run     # build, bundle, sign (ad-hoc), launch
make probe   # print live usage to the terminal, no UI
```

Requires Xcode command line tools. The app bundle lands in `build/Bua.app`.

## Privacy

Bua reads Claude Code's OAuth token from your login keychain (via the
`security` CLI, read-only) and sends it to exactly one place:
`api.anthropic.com/api/oauth/usage` — the same endpoint Claude Code's own
`/usage` screen uses. It never refreshes, stores, or logs the token, and it
never sees your conversations. If anything fails, the lotus simply rests.
