#!/usr/bin/env bash
#
# Finish a factory work session.
#
# Removes the CLAUDE_CODE_OAUTH_TOKEN secret from GitHub so no token sits in the
# public repo while the factory is idle. Re-add it with factory-session-start.sh
# next time. Idempotent — safe to run even if the secret is already gone, which
# also makes this the script to schedule as a nightly "forgot to stop" backstop.
set -euo pipefail

REPO="EduardBargues/software-factory-example"
SECRET_NAME="CLAUDE_CODE_OAUTH_TOKEN"

die() { printf 'error: %s\n' "$1" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || die "GitHub CLI 'gh' not found."

if gh secret list --repo "$REPO" | grep -q "^$SECRET_NAME"; then
  gh secret delete "$SECRET_NAME" --repo "$REPO" || die "Failed to delete $SECRET_NAME from $REPO."
  printf '\342\234\223 Removed %s from %s. The factory cannot run until you start a session again.\n' "$SECRET_NAME" "$REPO"
else
  printf '\342\234\223 %s is already absent from %s — nothing to do.\n' "$SECRET_NAME" "$REPO"
fi

printf '\nNote: this removes the token from GitHub; it does NOT revoke it. A token that\n'
printf 'leaked while present stays valid until you revoke it in your Claude account.\n'
