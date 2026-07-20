#!/usr/bin/env python3
"""Validate the plugin's manifests, skill layout, and corrected CLI guidance."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_SKILLS = {"vastai", "vastai-host", "vastai-host-support"}
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


manifest_paths = [
    ROOT / ".claude-plugin" / "plugin.json",
    ROOT / ".codex-plugin" / "plugin.json",
    ROOT / ".cursor-plugin" / "plugin.json",
]
manifest_path = next((path for path in manifest_paths if path.exists()), None)
require(manifest_path is not None, "no ecosystem plugin manifest found")

manifest: dict[str, object] = {}
if manifest_path is not None:
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"invalid manifest JSON: {exc}")

require(manifest.get("name") == "vastai", "manifest name must be vastai")
require(bool(re.fullmatch(r"\d+\.\d+\.\d+", str(manifest.get("version", "")))), "manifest version must be strict semver")
require(bool(manifest.get("description")), "manifest description is required")

if manifest_path and manifest_path.parent.name == ".codex-plugin":
    require(manifest.get("skills") == "./skills/", "Codex manifest must expose ./skills/")
    interface = manifest.get("interface")
    require(isinstance(interface, dict), "Codex manifest interface is required")
    if isinstance(interface, dict):
        for key in ("displayName", "shortDescription", "longDescription", "developerName", "category"):
            require(bool(interface.get(key)), f"Codex interface.{key} is required")

skill_dirs = {path.parent.name for path in (ROOT / "skills").glob("*/SKILL.md")}
require(skill_dirs == EXPECTED_SKILLS, f"expected skills {sorted(EXPECTED_SKILLS)}, found {sorted(skill_dirs)}")

skill_text: dict[str, str] = {}
for name in sorted(EXPECTED_SKILLS):
    path = ROOT / "skills" / name / "SKILL.md"
    if not path.exists():
        continue
    text = path.read_text(encoding="utf-8")
    skill_text[name] = text
    require(text.startswith("---\n"), f"{name}: missing YAML frontmatter")
    require(re.search(rf"(?m)^name:\s*{re.escape(name)}\s*$", text) is not None, f"{name}: frontmatter name mismatch")
    require(re.search(r"(?m)^description:\s*\S", text) is not None, f"{name}: description is required")

renter = skill_text.get("vastai", "")
host = skill_text.get("vastai-host", "")
support = skill_text.get("vastai-host-support", "")

for stale in ("does not offer network/shared volumes", "rebinds the calling API key", "tombstone state"):
    require(stale not in renter, f"vastai: stale guidance remains: {stale}")
require(re.search(r"(?m)^vastai create-team\b", renter) is None, "vastai: rejected create-team command remains")
require("vastai search network-volumes" in renter, "vastai: missing network-volume discovery")
require("vastai create network-volume" in renter, "vastai: missing network-volume creation")

require(re.search(r"--price_min(?!_bid)", host) is None, "vastai-host: use --price_min_bid, not --price_min")
for stale in ("gpu-trends 'gpu_name=", "does NOT offer network/shared volumes"):
    require(stale not in host, f"vastai-host: stale guidance remains: {stale}")
require(re.search(r"(?m)^vastai create-team\b", host) is None, "vastai-host: rejected create-team command remains")
require('vastai metrics gpu-trends "RTX 4090"' in host, "vastai-host: GPU trend filter must be positional")

for command in ("vastai self-test machine", "vastai dump-logs", "--support-bundle-dir", "--include-local-host-artifacts"):
    require(command in support, f"vastai-host-support: missing {command}")
require("actual Linux host" in support, "vastai-host-support: local artifact safety gate is required")

readme = (ROOT / "README.md").read_text(encoding="utf-8")
require("vastai-host-support" in readme, "README must document the host-support skill")
require("pytorch/pytorch:@vastai-automatic-tag" not in readme, "README contains an invalid automatic-tag image")

marketplace = ROOT / ".claude-plugin" / "marketplace.json"
if marketplace.exists():
    data = json.loads(marketplace.read_text(encoding="utf-8"))
    require(data.get("description") is not None, "Claude marketplace description is required")
    require(data.get("owner", {}).get("url") == "https://vast.ai", "Claude marketplace owner URL must be canonical")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)

print(f"Validated {ROOT.name}: {len(EXPECTED_SKILLS)} skills and {manifest_path.relative_to(ROOT)}")
