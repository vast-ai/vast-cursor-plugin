#!/usr/bin/env bash
# install.sh — install the Vast.ai Cursor plugin.
#
# Two install modes:
#   1. Project-local (default): copies into ./.cursor/ in the target directory
#      (default $PWD). Use `--target <dir>` to override.
#   2. User-global: --user copies into ~/.cursor/.
#
# What lands:
#   .cursor/skills/vastai/SKILL.md   — canonical skill (auto-invoke + /vastai)
#   .cursor/rules/vastai.mdc         — short auto-attach rule for IaC files
#
# Idempotent: re-running upgrades in place. Pass --force to overwrite, --dry-run to preview.

set -euo pipefail

MODE=project
TARGET=""
FORCE=0
DRY=0

while (("$#")); do
  case "$1" in
    --user) MODE=user; shift ;;
    --target) TARGET="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help)
      cat <<USAGE
Usage: install.sh [--user | --target <dir>] [--force] [--dry-run]

  --user           Install globally into ~/.cursor/ (instead of project-local).
  --target <dir>   Install into <dir>/.cursor/ (default: \$PWD).
  --force          Overwrite existing files without prompting.
  --dry-run        Print what would happen; don't write.
USAGE
      exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

REPO="$(cd "$(dirname "$0")" && pwd)"
SKILL_SRC="$REPO/.cursor/skills/vastai/SKILL.md"
RULE_SRC="$REPO/.cursor/rules/vastai.mdc"

if [[ $MODE == user ]]; then
  ROOT="$HOME/.cursor"
elif [[ -n "$TARGET" ]]; then
  # `realpath -m` canonicalizes without requiring the dir to exist (matters for
  # --dry-run against a non-existent target). Falls back to a manual resolve
  # if realpath is missing (rare on Linux).
  if command -v realpath >/dev/null 2>&1; then
    ROOT="$(realpath -m "$TARGET")/.cursor"
  else
    ROOT="$(mkdir -p "$TARGET" && cd "$TARGET" && pwd)/.cursor"
  fi
else
  ROOT="$PWD/.cursor"
fi
SKILL_DST="$ROOT/skills/vastai/SKILL.md"
RULE_DST="$ROOT/rules/vastai.mdc"

# When invoked from inside the plugin repo with no --target, the default
# `$PWD/.cursor` IS the source dir → self-copy. Silently promote to a global
# (--user) install so the script always succeeds for that common case.
if [[ "$SKILL_SRC" -ef "$SKILL_DST" || "$RULE_SRC" -ef "$RULE_DST" ]]; then
  if [[ $MODE == project && -z "$TARGET" ]]; then
    echo "notice: \$PWD is the plugin repo itself; installing globally into ~/.cursor instead." >&2
    MODE=user
    ROOT="$HOME/.cursor"
    SKILL_DST="$ROOT/skills/vastai/SKILL.md"
    RULE_DST="$ROOT/rules/vastai.mdc"
    echo "  new target: $ROOT" >&2
    echo
  else
    echo "error: source and destination are the same directory ($ROOT)." >&2
    echo "       pass --target <dir> or use --user." >&2
    exit 1
  fi
fi

run() { if [[ $DRY -eq 1 ]]; then echo "[dry-run] $*"; else eval "$@"; fi; }

require_no_clobber() {
  local target="$1"
  [[ -e "$target" && $FORCE -eq 0 ]] || return 0
  echo "refusing to overwrite $target (pass --force to allow)" >&2
  exit 1
}

echo "Installing vast-cursor-plugin from $REPO"
echo "  mode    : $MODE"
echo "  target  : $ROOT"
echo

require_no_clobber "$SKILL_DST"
require_no_clobber "$RULE_DST"

run "mkdir -p '$(dirname "$SKILL_DST")'"
run "cp '$SKILL_SRC' '$SKILL_DST'"
echo "✓ skill installed: $SKILL_DST"

run "mkdir -p '$(dirname "$RULE_DST")'"
run "cp '$RULE_SRC' '$RULE_DST'"
echo "✓ rule installed: $RULE_DST"

echo
echo "Done. Restart Cursor (or reload the workspace) to pick up the new skill + rule."
echo "Invoke: /vastai in Agent chat, or describe what you want and the skill auto-loads."
