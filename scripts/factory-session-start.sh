#!/usr/bin/env bash
#
# Start a factory work session.
#
# Pushes the Claude Code OAuth token from 1Password into the
# CLAUDE_CODE_OAUTH_TOKEN GitHub secret so agent runs can authenticate to Claude.
# Run ./scripts/factory-session-stop.sh when you finish, to remove it again — so
# no token sits in the public repo while the factory is idle.
#
# The token is read from 1Password into memory and piped to GitHub Secrets; it is
# never written to disk, echoed, or placed in a process argument.
set -euo pipefail

REPO="EduardBargues/software-factory-example"
SECRET_NAME="CLAUDE_CODE_OAUTH_TOKEN"
# Where the token lives in 1Password (op://<vault>/<item>/<field>).
# Override per-run with FACTORY_OP_REF, or edit this default once.
OP_REF="${FACTORY_OP_REF:-op://Private/Software Factory Claude Token/credential}"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }

command -v op >/dev/null 2>&1 || die "1Password CLI 'op' not found — install it, then re-run."
command -v gh >/dev/null 2>&1 || die "GitHub CLI 'gh' not found."

# Ensure op has a usable session (desktop-app integration or 'op signin').
if ! op whoami >/dev/null 2>&1; then
  printf 'Signing in to 1Password...\n'
  eval "$(op signin)" 2>/dev/null || die "1Password sign-in failed. Run 'op account add' first, or enable the desktop-app CLI integration."
fi

printf 'Reading the token from 1Password (%s)...\n' "$OP_REF"
token="$(op read "$OP_REF")" || die "Could not read the token. Check FACTORY_OP_REF points at the item (op://vault/item/field)."
[ -n "$token" ] || die "1Password returned an empty value for $OP_REF."

printf '%s' "$token" | gh secret set "$SECRET_NAME" --repo "$REPO" || die "Failed to set $SECRET_NAME on $REPO."
unset token

if gh secret list --repo "$REPO" | grep -q "^$SECRET_NAME"; then
  printf '\342\234\223 %s is set on %s. The factory can run.\n' "$SECRET_NAME" "$REPO"
  printf '  Run ./scripts/factory-session-stop.sh when you finish.\n'
else
  die "Set reported success but $SECRET_NAME is not listed — check manually."
fi
