#!/usr/bin/env bash
#
# Start a factory work session.
#
# Prompts you to paste the Claude Code OAuth token, then stores it as the
# CLAUDE_CODE_OAUTH_TOKEN GitHub secret so agent runs can authenticate to Claude.
# Run ./scripts/factory-session-stop.sh when you finish, to remove it again — so
# no token sits in the public repo while the factory is idle.
#
# Generate the token once with `claude setup-token` (it is valid ~1 year) and
# keep it wherever you like (a password manager, etc.). This script is agnostic
# to where it came from: it only takes what you paste and pipes it straight to
# GitHub Secrets via stdin — never to disk, a log, or a process argument. The
# paste is hidden.
set -euo pipefail

REPO="EduardBargues/software-factory-example"
SECRET_NAME="CLAUDE_CODE_OAUTH_TOKEN"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || die "GitHub CLI 'gh' not found."

printf 'Paste the Claude Code OAuth token (input hidden), then press Enter:\n> '
# `|| true`: under `set -e`, read returns non-zero at EOF (e.g. piped input with
# no trailing newline) and would abort silently; the emptiness check below is the
# real guard for "nothing entered".
read -rs token || true
printf '\n'
[ -n "${token:-}" ] || die "No token entered — nothing changed."

printf '%s' "$token" | gh secret set "$SECRET_NAME" --repo "$REPO" || die "Failed to set $SECRET_NAME on $REPO."
unset token

if gh secret list --repo "$REPO" | grep -q "^$SECRET_NAME"; then
  printf '\342\234\223 %s is set on %s. The factory can run.\n' "$SECRET_NAME" "$REPO"
  printf '  Run ./scripts/factory-session-stop.sh when you finish.\n'
else
  die "Set reported success but $SECRET_NAME is not listed — check manually."
fi
