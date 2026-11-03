# remote-login

Sign in to one of Claude's browsers from your phone. Claude sends a link (in chat, and optionally as a push); the page is a full-screen live view that acts like a browser (tap a field and the phone keyboard types into it live, swipe to scroll), and Claude carries on once you tap "Terminé". Credentials go phone -> this server -> browser, never through Claude, and are never logged.

- `pane` target: the Claude desktop app's built-in browser pane (Mac must be unlocked).
- `headless` target: a dedicated headless Brave on CDP 127.0.0.1:9334 (works with the Mac locked).

Needs macOS, [Tailscale](https://tailscale.com) on the Mac and the phone, [uv](https://docs.astral.sh/uv/), Brave (headless target) and the Claude desktop app (pane target). The page listens on the Mac's Tailscale address only, behind a one-time token.

`--notify` runs `~/.config/remote-login/notify LINK MESSAGE` (or `$REMOTE_LOGIN_NOTIFY`), an executable of your own that sends the link to your phone, for example:

```sh
#!/bin/sh
curl -s -d "$2 $1" https://ntfy.sh/your-private-topic
```

```
./build.sh                                   # builds bin/rl-helper (Swift)
remote-login serve --host example.com --url https://example.com/login --notify
remote-login headless-stop
```

Files: `remote-login` (server, uv script), `page.html` (phone page), `helper/main.swift` (locates the pane via Accessibility, posts mouse/keyboard events), `SKILL.md` (Claude Code skill: copy it to `~/.claude/skills/remote-login/`).

## End-to-end test (pane)

`test/login-fixture.py` serves a sign-in page on 127.0.0.1:8799 (test account `demo` / `demo-pass-8799`). Open `http://login.localhost:8799/account` in the built-in browser, run `remote-login serve --target pane --host login.localhost`, sign in through the phone page, then reload `/account` with the browser tools: it reads "Connecté en tant que demo". Verified 2026-10-31.

## Test (headless) without touching a live sign-in

`REMOTE_LOGIN_CDP_PORT` and `REMOTE_LOGIN_PROFILE` move the headless Brave elsewhere, e.g. `REMOTE_LOGIN_CDP_PORT=9344 REMOTE_LOGIN_PROFILE=/tmp/rl ./remote-login serve --target headless --bind 127.0.0.1 --port 8792 --url http://127.0.0.1:8799/`. Verified 2026-11-03 with Playwright (Pixel 7): tap field, live typing, Enter, swipe scroll.

## License

MIT, see `LICENSE`.
