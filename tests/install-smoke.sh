#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

bash -n "$repo/install.sh"
"$repo/install.sh" --target "$test_root/project" --force

for skill in vastai vastai-host vastai-host-support; do
  diff -qr "$repo/skills/$skill" "$test_root/project/.cursor/skills/$skill"
done

diff -q "$repo/rules/vastai.mdc" "$test_root/project/.cursor/rules/vastai.mdc"

"$repo/install.sh" --target "$test_root/dry-run" --dry-run >/dev/null
test ! -e "$test_root/dry-run"
