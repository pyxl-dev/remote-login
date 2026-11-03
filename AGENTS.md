# Instructions for AI agents

You are an AI coding agent (Claude Code, Codex, Cursor...) and your user asked you to install or use **remote-login**. This file tells you how. Keep the safety rules at the end: they matter more than the rest.

## What it does

When a browser you drive hits a sign-in page, a 2FA prompt or a captcha, `remote-login` lets **your user** sign in from their phone. It serves a one-time page on the Mac's Tailscale address. The page is a live, full-screen view of your browser: they tap and type on their phone, the input lands in your browser, and you carry on once they tap "Terminé". You never see the credentials.

Two targets:

| Target | Browser | Needs | Continue the task with |
| --- | --- | --- | --- |
| `pane` | Claude desktop app's built-in browser pane | Mac unlocked, the session with its Browser pane on screen | the app's browser tools |
| `headless` | dedicated headless Brave, CDP `127.0.0.1:9334` | Brave installed; works with the Mac locked | any CDP client on `http://127.0.0.1:9334` |

`auto` (default) picks `pane` when possible, else `headless`.

## Install

Run, then read the output: every line starts with `✓`, `!` (optional piece missing) or `✗` (blocking).

```sh
curl -fsSL https://raw.githubusercontent.com/pyxl-dev/remote-login/main/install.sh | sh
```

- `✗ uv is missing`: tell the user and give them the command printed. Do not install system tools without asking.
- `! Tailscale ...`: the phone link only works on the user's tailnet. Ask them to install Tailscale on the Mac and the phone and sign in to the same account.
- Check: `remote-login serve --help` prints the usage.

For Claude Code, the installer also puts the skill in `~/.claude/skills/remote-login/SKILL.md`; it is picked up on the next session. Other agents: read `SKILL.md` in this repository, it is the full procedure.

## Use

1. `pane` target only: open the sign-in page in the built-in browser and keep the session and its Browser pane on screen.
2. Start the server **in the background** (it blocks until the user is done):
   ```sh
   remote-login serve --host <site host> --url <sign-in URL> [--notify]
   ```
3. Read the `TARGET <t>` and `LINK <url>` lines it prints. Give the user the link and one line: tap a field to type with the phone keyboard, swipe to scroll, "Terminé" when signed in.
4. Wait for the process to exit, without polling the page. Exit codes: `0` + `DONE` signed in; `3` + `CANCELLED` the user gave up, ask what to do; `2` + `TIMEOUT` after 15 minutes (`--minutes`).
5. Check the sign-in worked in the browser, then continue the task.
6. Headless target: `remote-login headless-stop` when the task is over. The profile (`~/.cache/remote-login/profile`) and its sign-ins stay on disk.

`--notify` runs `~/.config/remote-login/notify LINK MESSAGE` if the user created that script (push service, chat bot...). Without it, give the link in chat.

## Safety rules

- Never ask the user to send a password, a code or a recovery key in chat. Never type one yourself. That is the whole point of the tool.
- The link holds a one-time token: give it to the user only, never paste it into a page, an issue or a log.
- The server listens on the Tailscale address only. Do not pass `--bind 0.0.0.0` or expose the port.
- Start it only when a sign-in is actually needed, and only for a site the user's task involves.
