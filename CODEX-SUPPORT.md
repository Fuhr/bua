# Future: Codex (OpenAI) provider support

Parked 2026-06-18. A second friend uses Codex, not Claude Code — Bua currently
only reads Claude's keychain token, so on a Codex-only Mac the lotus just rests.

## Why it's a clean fit

Codex's `/status` already surfaces `Rate Limits Remaining: 5h X% · Weekly Y%` —
two numbers that map 1:1 onto Bua's existing **session bar + weekly bar**. The
lotus, bars, and `ColorJourney` are already provider-agnostic (they consume
`UsageModel`). This is the seam the v1 handover deliberately deferred:
"build the UsageModel/UsageFetcher seam when a second provider actually arrives."

## The parallel

| Layer | Claude (built) | Codex (to build) |
|---|---|---|
| Credentials | login keychain `Claude Code-credentials` via `/usr/bin/security` | `~/.codex/auth.json` (plaintext under `CODEX_HOME`, default `~/.codex`); or OS keyring per `cli_auth_credentials_store`. A plain file read is *simpler* than the keychain dance. |
| Usage signal | `GET api.anthropic.com/api/oauth/usage` → session% + weekly% | the request `/status` makes against `https://chatgpt.com/backend-api/` → 5h% + weekly% |
| UI | session + week bars + lotus | identical — same two-window model |

## Work, in order

1. Extract a `UsageFetcher` protocol → `AnthropicUsageFetcher` (move existing
   logic) + `CodexUsageFetcher` (new). Both return the same `Usage` struct.
2. `CodexCredentialReader` — read/parse `~/.codex/auth.json` (honor `CODEX_HOME`;
   keyring fallback later). Same discipline as Claude: **read-only, never refresh**.
3. **The usage call — the one unknown.** Pin down the exact request `/status`
   fires at `chatgpt.com/backend-api/` (proxy-trace it, or check whether the
   rate-limit info rides response headers). Lenient Codable + rest-on-failure.
4. Provider auto-detect — Claude creds → Claude; Codex creds → Codex; both → the
   "multi-provider pond" UI decision (still open). Codex-only friend auto-lands
   on Codex, zero config.
5. Label — `"claude session"` → provider-aware (`"codex session"`).

## Effort / gate

Steps 1–2, 4–5 ≈ a focused half-day — the architecture was built for this.
**Step 3 is the gate and can't start without a Codex account to observe** — same
way the Anthropic endpoint was reverse-engineered. Cheapest unblock: have the
Codex friend run `codex`, open `/status`, and capture the outbound request
(~5 min proxy trace). Same undocumented-endpoint fragility as today's Anthropic
call — but "resting" is already the designed failure mode, so no new risk class.

## Sources

- Codex auth & credential storage: https://developers.openai.com/codex/auth
- Codex config (`cli_auth_credentials_store`, base URL): https://developers.openai.com/codex/config-reference
- ChatGPT-plan rate limits (5h + weekly, `/status`): https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- `/codex:usage` feature request (appetite for a usage surface): https://github.com/openai/codex-plugin-cc/issues/102
