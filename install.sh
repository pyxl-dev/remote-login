#!/bin/sh
# remote-login installer.
#
#   curl -fsSL https://raw.githubusercontent.com/pyxl-dev/remote-login/main/install.sh | sh
#   ./install.sh               # from a clone: installs that clone
#   ./install.sh --uninstall
#
# Puts the code in ~/.local/share/remote-login (or uses this clone), links the
# CLI into ~/.local/bin, builds the Swift helper and installs the Claude Code
# skill. Re-run it to update. Nothing outside your home folder is touched.
set -eu

REPO="${REMOTE_LOGIN_REPO:-https://github.com/pyxl-dev/remote-login.git}"
DEST="${REMOTE_LOGIN_HOME:-$HOME/.local/share/remote-login}"
BIN="$HOME/.local/bin"
SKILL="$HOME/.claude/skills/remote-login"

if [ -t 1 ]; then B=$(printf '\033[1m'); G=$(printf '\033[32m'); Y=$(printf '\033[33m'); R=$(printf '\033[31m'); N=$(printf '\033[0m'); else B= G= Y= R= N=; fi
ok()   { printf '%s✓%s %s\n' "$G" "$N" "$1"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$1"; }
die()  { printf '%s✗%s %s\n' "$R" "$N" "$1" >&2; exit 1; }

if [ "${1:-}" = "--uninstall" ]; then
  rm -f "$BIN/remote-login"; ok "removed $BIN/remote-login"
  rm -rf "$SKILL"; ok "removed $SKILL"
  if [ -d "$DEST/.git" ]; then rm -rf "$DEST"; ok "removed $DEST"; fi
  echo "Left in place: ~/.cache/remote-login (headless browser profile) and ~/.config/remote-login."
  exit 0
fi

printf '%sremote-login%s installer\n\n' "$B" "$N"
[ "$(uname -s)" = "Darwin" ] || die "macOS only (the pane target drives the Claude desktop app)."

# 1. Code: this clone, or a managed one in ~/.local/share.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
if [ -n "$HERE" ] && [ -f "$HERE/remote-login" ] && [ -f "$HERE/page.html" ]; then
  DEST="$HERE"
  ok "using this clone: $DEST"
elif [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --ff-only -q || die "could not update $DEST (local changes?)"
  ok "updated $DEST"
else
  command -v git >/dev/null || die "git is missing: run  xcode-select --install"
  mkdir -p "$(dirname "$DEST")"
  git clone -q --depth 1 "$REPO" "$DEST" || die "could not download $REPO"
  ok "downloaded to $DEST"
fi

# 2. Requirements.
if command -v uv >/dev/null; then ok "uv found"
else die "uv is missing (it runs the Python script). Install it, then re-run:  curl -LsSf https://astral.sh/uv/install.sh | sh"; fi
if command -v tailscale >/dev/null && tailscale ip -4 >/dev/null 2>&1; then ok "Tailscale up ($(tailscale ip -4 | head -1))"
else warn "Tailscale not found or not connected: the phone link needs it (https://tailscale.com/download), or pass --bind."; fi
if [ -x "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" ]; then ok "Brave found (headless target)"
else warn "Brave not found: the headless target needs it (https://brave.com/download). The pane target still works."; fi

# 3. Swift helper for the pane target.
if command -v swiftc >/dev/null; then
  if "$DEST/build.sh" >/dev/null 2>&1; then ok "built bin/rl-helper (pane target)"
  else warn "helper build failed: run $DEST/build.sh to see why. The headless target still works."; fi
else
  warn "swiftc missing (xcode-select --install): no pane target, headless still works."
fi

# 4. CLI on the PATH.
mkdir -p "$BIN"
ln -sf "$DEST/remote-login" "$BIN/remote-login"
chmod +x "$DEST/remote-login"
ok "linked $BIN/remote-login"
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not on your PATH: add  export PATH=\"\$HOME/.local/bin:\$PATH\"  to ~/.zshrc";; esac

# 5. Claude Code skill. A skill you edited yourself is kept.
mkdir -p "$SKILL"
if [ -f "$SKILL/SKILL.md" ] && ! cmp -s "$SKILL/SKILL.md" "$DEST/SKILL.md"; then
  cp "$DEST/SKILL.md" "$SKILL/SKILL.md.new"
  warn "kept your $SKILL/SKILL.md (the new version is next to it as SKILL.md.new)"
else
  cp "$DEST/SKILL.md" "$SKILL/SKILL.md"
  ok "installed the Claude Code skill in $SKILL"
fi

# 6. Optional push of the link to the phone.
if [ -x "$HOME/.config/remote-login/notify" ]; then ok "notify script found"
else echo "  Optional: create ~/.config/remote-login/notify (executable, gets LINK MESSAGE) to push the link to your phone."; fi

printf '\n%sDone.%s Try:  remote-login serve --target headless --url https://example.com\n' "$B" "$N"
echo "In Claude Code, the skill is picked up on the next session: ask Claude to use remote-login when a site needs you to sign in."
