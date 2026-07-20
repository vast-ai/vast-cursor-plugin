#!/usr/bin/env bash
# install.sh — install the Vast.ai Cursor plugin.
#
# Two install modes:
#   1. Project-local (default): copies into ./.cursor/ in the target directory
#      (default $PWD). Use `--target <dir>` to override.
#   2. User-global: --user copies into ~/.cursor/.
#
# What lands:
#   .cursor/skills/*/SKILL.md         — renter, host, and host-support skills
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
    --target)
      [[ $# -ge 2 ]] || { echo "--target requires a directory" >&2; exit 2; }
      TARGET="$2"; shift 2 ;;
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
# Source files live at the Cursor plugin-spec paths (skills/, rules/) at the
# repo root. install.sh copies them into the user/project .cursor/ tree.
SKILLS_SRC="$REPO/skills"
RULE_SRC="$REPO/rules/vastai.mdc"

if [[ $MODE == user ]]; then
  ROOT="$HOME/.cursor"
elif [[ -n "$TARGET" ]]; then
  # Avoid GNU-only `realpath -m`; project targets need not exist for dry-runs.
  if [[ "$TARGET" = /* ]]; then
    PROJECT_ROOT="${TARGET%/}"
  else
    PROJECT_ROOT="${PWD%/}/${TARGET%/}"
  fi
  ROOT="$PROJECT_ROOT/.cursor"
else
  ROOT="$PWD/.cursor"
fi
SKILLS_DST="$ROOT/skills"
RULE_DST="$ROOT/rules/vastai.mdc"

# If $PWD is the plugin repo itself (detected via the manifest file), a default
# project install would create a stray `.cursor/` dir inside the source repo.
# Silently promote to a global (--user) install so the script always does the
# right thing for that common case.
if [[ $MODE == project && -z "$TARGET" && -f "$REPO/.cursor-plugin/plugin.json" && "$PWD" -ef "$REPO" ]]; then
  echo "notice: \$PWD is the plugin repo itself; installing globally into ~/.cursor instead." >&2
  MODE=user
  ROOT="$HOME/.cursor"
  SKILLS_DST="$ROOT/skills"
  RULE_DST="$ROOT/rules/vastai.mdc"
  echo "  new target: $ROOT" >&2
  echo
fi

run() {
  if [[ $DRY -eq 1 ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

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

require_no_clobber "$RULE_DST"

for skill_src in "$SKILLS_SRC"/*; do
  [[ -f "$skill_src/SKILL.md" ]] || continue
  skill_name="$(basename "$skill_src")"
  skill_dst="$SKILLS_DST/$skill_name/SKILL.md"
  require_no_clobber "$skill_dst"
  run mkdir -p "$(dirname "$skill_dst")"
  run cp "$skill_src/SKILL.md" "$skill_dst"
  echo "✓ skill installed: $skill_dst"
done

run mkdir -p "$(dirname "$RULE_DST")"
run cp "$RULE_SRC" "$RULE_DST"
echo "✓ rule installed: $RULE_DST"

echo
echo "Done. Restart Cursor (or reload the workspace) to pick up the new skills + rule."
echo "Invoke: /vastai in Agent chat, or describe what you want and the skill auto-loads."
